<?php

namespace App\Services;

use App\Enums\StaffRole;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class StaffManagementService
{
    public function __construct(
        protected AuditService $audit,
    ) {}

    /**
     * Provision a new staff user.
     *
     * @param  array<string, mixed>  $validated
     *
     * @throws ValidationException
     */
    public function createStaff(User $admin, array $validated): User
    {
        $staffRole = StaffRole::tryFrom((string) $validated['role']);
        if ($staffRole === null) {
            throw ValidationException::withMessages([
                'role' => ['The selected role is invalid.'],
            ]);
        }

        $role = Role::query()->firstOrCreate(
            ['name' => $staffRole->value],
            ['label' => $staffRole->label()],
        );

        $name = trim((string) $validated['name']);
        $email = Str::lower(trim((string) $validated['email']));
        $isActive = array_key_exists('is_active', $validated) ? (bool) $validated['is_active'] : true;
        $hashedPassword = Hash::make((string) $validated['password']);

        return DB::transaction(function () use ($admin, $role, $name, $email, $isActive, $hashedPassword): User {
            try {
                $user = new User;
                $user->name = $name;
                $user->email = $email;
                $user->password = $hashedPassword;
                $user->role_id = $role->id;
                $user->is_active = $isActive;
                $user->save();
            } catch (UniqueConstraintViolationException) {
                throw ValidationException::withMessages([
                    'email' => ['The email has already been taken.'],
                ]);
            }

            $this->audit->record($admin, 'staff.created', 'user', $user->id, [
                'email' => $email,
                'role' => $role->name,
                'is_active' => $isActive,
            ]);

            return $user->load('role');
        });
    }

    /**
     * Update an existing staff member's attributes.
     *
     * @param  array<string, mixed>  $validated
     *
     * @throws ValidationException
     */
    public function updateStaff(User $admin, User $subject, array $validated): User
    {
        return DB::transaction(function () use ($admin, $subject, $validated): User {
            /** @var User $target */
            $target = User::query()->where('id', $subject->id)->lockForUpdate()->firstOrFail();
            $target->load('role');
            $currentRole = $target->role;

            $wasOperationalAdmin = $target->is_active && $currentRole?->staffRole() === StaffRole::Admin;

            $newRoleName = $validated['role'] ?? $currentRole?->name;
            $newIsActive = array_key_exists('is_active', $validated) ? (bool) $validated['is_active'] : $target->is_active;
            $willBeOperationalAdmin = $newIsActive && $newRoleName === StaffRole::Admin->value;

            // Enforce last-operational-admin invariant deterministically under lock
            if ($wasOperationalAdmin && ! $willBeOperationalAdmin) {
                /** @var Role $adminRole */
                $adminRole = Role::query()->firstOrCreate(
                    ['name' => StaffRole::Admin->value],
                    ['label' => StaffRole::Admin->label()],
                );
                $adminRole = Role::query()->where('id', $adminRole->id)->lockForUpdate()->firstOrFail();
                $activeAdminCount = User::query()
                    ->where('role_id', $adminRole->id)
                    ->where('is_active', true)
                    ->count();

                if ($activeAdminCount <= 1) {
                    abort(409, 'Cannot demote or deactivate the last operational administrator.');
                }
            }

            $nameChanged = false;
            $oldName = $target->name;
            if (isset($validated['name'])) {
                $trimmedName = trim((string) $validated['name']);
                if ($trimmedName !== $target->name) {
                    $nameChanged = true;
                    $target->name = $trimmedName;
                }
            }

            $emailChanged = false;
            $oldEmail = $target->email;
            if (isset($validated['email'])) {
                $normEmail = Str::lower(trim((string) $validated['email']));
                if ($normEmail !== $target->email) {
                    $emailChanged = true;
                    $target->email = $normEmail;
                }
            }

            $roleChanged = false;
            $oldRoleName = $currentRole?->name;
            $newRole = null;
            if (isset($validated['role']) && $validated['role'] !== $currentRole?->name) {
                $roleChanged = true;
                $targetStaffRole = StaffRole::tryFrom((string) $validated['role']);
                if ($targetStaffRole === null) {
                    throw ValidationException::withMessages([
                        'role' => ['The selected role is invalid.'],
                    ]);
                }
                $newRole = Role::query()->firstOrCreate(
                    ['name' => $targetStaffRole->value],
                    ['label' => $targetStaffRole->label()],
                );
                $target->role_id = $newRole->id;
            }

            $activationChanged = false;
            $oldActive = (bool) $target->is_active;
            if (array_key_exists('is_active', $validated) && (bool) $validated['is_active'] !== (bool) $target->is_active) {
                $activationChanged = true;
                $target->is_active = (bool) $validated['is_active'];
            }

            try {
                $target->save();
            } catch (UniqueConstraintViolationException) {
                throw ValidationException::withMessages([
                    'email' => ['The email has already been taken.'],
                ]);
            }

            // Token revocation policy:
            // Role change, email change, or deactivation revokes all tokens.
            if ($roleChanged || $emailChanged || ($activationChanged && ! $target->is_active)) {
                $target->tokens()->delete();
            }

            // Record distinct, immutable audit events
            if ($roleChanged && $newRole !== null) {
                $this->audit->record($admin, 'staff.role_changed', 'user', $target->id, [
                    'from_role' => $oldRoleName,
                    'to_role' => $newRole->name,
                ]);
            }

            if ($activationChanged) {
                $action = $target->is_active ? 'staff.activated' : 'staff.deactivated';
                $this->audit->record($admin, $action, 'user', $target->id, [
                    'from_active' => $oldActive,
                    'to_active' => $target->is_active,
                ]);
            }

            if ($nameChanged || $emailChanged) {
                $updatedFields = [];
                if ($nameChanged) {
                    $updatedFields['name'] = [
                        'from' => $oldName,
                        'to' => $target->name,
                    ];
                }
                if ($emailChanged) {
                    $updatedFields['email'] = [
                        'from' => $oldEmail,
                        'to' => $target->email,
                    ];
                }

                $this->audit->record($admin, 'staff.updated', 'user', $target->id, $updatedFields);
            }

            return $target->load('role');
        });
    }

    /**
     * Reset a staff member's password and revoke all personal access tokens.
     */
    public function resetPassword(User $admin, User $subject, string $newPassword): User
    {
        return DB::transaction(function () use ($admin, $subject, $newPassword): User {
            /** @var User $target */
            $target = User::query()->where('id', $subject->id)->lockForUpdate()->firstOrFail();
            $target->password = Hash::make($newPassword);
            $target->save();

            // Revoke all existing personal access tokens
            $target->tokens()->delete();

            // Append audit event with zero secret/password metadata
            $this->audit->record($admin, 'staff.password_reset', 'user', $target->id, null);

            return $target->load('role');
        });
    }

    /**
     * Explicitly revoke all active tokens for a staff member.
     */
    public function revokeTokens(User $admin, User $subject, string $reason): User
    {
        return DB::transaction(function () use ($admin, $subject, $reason): User {
            /** @var User $target */
            $target = User::query()->where('id', $subject->id)->lockForUpdate()->firstOrFail();
            $target->tokens()->delete();

            $this->audit->record($admin, 'staff.tokens_revoked', 'user', $target->id, [
                'reason' => $reason,
            ]);

            return $target->load('role');
        });
    }
}
