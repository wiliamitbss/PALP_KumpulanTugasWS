<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/products', function () {
    return response()->json([
    ['id' => 1, 'name' => 'Mango Sagoo', 'price' => 25000],
    ['id' => 2, 'name' => 'Nasi Kuning', 'price' => 15000]
    ]);
});

use App\Http\Controllers\Api\ProductController;

// ini akan otomatis buat semua route RESTful (index, store, show, update, destroy)
Route::apiResource('products', ProductController::class);
