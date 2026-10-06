<?php

namespace Tests\Unit;

use App\Inventory\Quantity;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class QuantityTest extends TestCase
{
    public function test_exact_parsing_formatting_and_arithmetic(): void
    {
        $this->assertSame(1, Quantity::parse('0.0001'));
        $this->assertSame(1800000, Quantity::parse('180'));
        $this->assertSame(12300, Quantity::parse('1.23'));
        $this->assertSame(-12300, Quantity::parse('-1.23', true));
        $this->assertSame('0.0000', Quantity::format(0));
        $this->assertSame('-1.2300', Quantity::format(-12300));
        $this->assertSame(99999999999999, Quantity::parse('9999999999.9999'));
        $this->assertSame('9999999999.9999', Quantity::format(99999999999999));
        $this->assertSame(3000, Quantity::add(Quantity::parse('0.1'), Quantity::parse('0.2')));
        $this->assertSame(1, Quantity::subtract(Quantity::parse('1'), Quantity::parse('0.9999')));
        $this->assertSame(540000, Quantity::multiply(Quantity::parse('18'), 3));
        $this->assertSame(-6, Quantity::multiply(-2, 3));
        $this->assertSame(0, Quantity::multiply(0, PHP_INT_MAX));
    }

    public static function invalidDecimals(): array
    {
        return ['float' => [1.0], 'integer' => [1], 'null' => [null], 'bool' => [false], 'array' => [[]],
            'exponent' => ['1e2'], 'positive sign' => ['+1'], 'leading zeros' => ['01'], 'negative unsigned' => ['-1'],
            'missing integer' => ['.1'], 'missing fraction' => ['1.'], 'too many decimals' => ['0.00001'],
            'overflow integer' => ['10000000000'], 'spaces' => [' 1'], 'newline' => ["1\n"], 'separator' => ['1,000'], 'non-ascii' => ['១']];
    }

    #[DataProvider('invalidDecimals')]
    public function test_rejects_noncanonical_or_nonstring_quantities(mixed $value): void
    {
        $this->expectException(InvalidArgumentException::class);
        Quantity::parse($value);
    }

    public static function overflowingArithmetic(): array
    {
        return ['add' => ['add', Quantity::MAX_SCALED, 1], 'subtract' => ['subtract', -Quantity::MAX_SCALED, 1],
            'multiply' => ['multiply', Quantity::MAX_SCALED, 2], 'multiplication integer overflow' => ['multiply', 10000, PHP_INT_MAX],
            'negative count' => ['multiply', 1, -1], 'operand out of bounds' => ['add', PHP_INT_MAX, 0]];
    }

    #[DataProvider('overflowingArithmetic')]
    public function test_overflow_is_rejected_before_rounding_or_native_integer_overflow(string $method, int $left, int $right): void
    {
        $this->expectException(InvalidArgumentException::class);
        Quantity::$method($left, $right);
    }

    public function test_signed_negative_zero_is_rejected(): void
    {
        $this->expectException(InvalidArgumentException::class);
        Quantity::parse('-0.0000', true);
    }

    public static function floatOperands(): array
    {
        return ['format' => ['format', [1.5]], 'add' => ['add', [1.0, 1]],
            'subtract' => ['subtract', [1, 1.0]], 'multiply quantity' => ['multiply', [1.0, 1]],
            'multiply units' => ['multiply', [1, 1.5]], 'scaled string' => ['format', ['1']]];
    }

    #[DataProvider('floatOperands')]
    public function test_arithmetic_never_coerces_float_or_string_scaled_operands(string $method, array $operands): void
    {
        $this->expectException(InvalidArgumentException::class);
        Quantity::$method(...$operands);
    }
}
