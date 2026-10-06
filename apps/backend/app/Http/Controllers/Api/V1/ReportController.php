<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Reports\DateRangeReportRequest;
use App\Http\Requests\Reports\InventoryReportRequest;
use App\Http\Requests\Reports\ReconciliationReportRequest;
use App\Http\Requests\Reports\TopProductsReportRequest;
use App\Services\ReportService;
use Illuminate\Http\JsonResponse;

class ReportController extends Controller
{
    public function __construct(
        protected readonly ReportService $reportService,
    ) {}

    public function overview(DateRangeReportRequest $request): JsonResponse
    {
        $period = $this->reportService->resolvePeriod(
            $request->query('from_date'),
            $request->query('to_date')
        );

        $overview = $this->reportService->getOverview($period);

        return response()->json([
            'data' => $overview,
        ]);
    }

    public function salesTrend(DateRangeReportRequest $request): JsonResponse
    {
        $period = $this->reportService->resolvePeriod(
            $request->query('from_date'),
            $request->query('to_date')
        );

        $trend = $this->reportService->getSalesTrend($period);

        return response()->json([
            'data' => $trend['data'],
            'period' => $trend['period'],
        ]);
    }

    public function paymentMethods(DateRangeReportRequest $request): JsonResponse
    {
        $period = $this->reportService->resolvePeriod(
            $request->query('from_date'),
            $request->query('to_date')
        );

        $methods = $this->reportService->getPaymentMethods($period);

        return response()->json([
            'data' => $methods['data'],
            'currency' => $methods['currency'],
            'period' => $methods['period'],
        ]);
    }

    public function topProducts(TopProductsReportRequest $request): JsonResponse
    {
        $period = $this->reportService->resolvePeriod(
            $request->query('from_date'),
            $request->query('to_date')
        );

        $limit = (int) ($request->query('limit', 10));
        $topProducts = $this->reportService->getTopProducts($period, $limit);

        return response()->json([
            'data' => $topProducts['data'],
            'currency' => $topProducts['currency'],
            'period' => $topProducts['period'],
        ]);
    }

    public function inventory(InventoryReportRequest $request): JsonResponse
    {
        $status = $request->query('status');
        $search = $request->query('search');
        $page = (int) ($request->query('page', 1));
        $perPage = (int) ($request->query('per_page', 25));

        $result = $this->reportService->getInventorySummary($status, $search, $page, $perPage);

        return response()->json($result);
    }

    public function reconciliation(ReconciliationReportRequest $request): JsonResponse
    {
        $page = (int) ($request->query('page', 1));
        $perPage = (int) ($request->query('per_page', 25));

        $result = $this->reportService->getReconciliationSummary($page, $perPage);

        return response()->json($result);
    }
}
