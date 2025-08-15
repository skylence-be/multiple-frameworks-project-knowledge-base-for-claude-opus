# Filament v4 Performance Optimization Guide

## Database Optimization

### 1. Query Optimization Strategies

#### Eager Loading
```php
// OPTIMIZE: Always eager load relationships
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->with([
            'category:id,name',  // Select only needed columns
            'tags:id,name',
            'media' => function ($query) {
                $query->where('collection_name', 'featured');
            }
        ])
        ->withCount(['orders', 'reviews'])
        ->withSum('orders', 'total')
        ->withAvg('reviews', 'rating');
}
```

#### Database Indexing
```php
// OPTIMIZE: Add indexes for frequently queried columns
Schema::table('products', function (Blueprint $table) {
    // Single column indexes
    $table->index('status');
    $table->index('created_at');
    $table->index('category_id');
    
    // Composite indexes for common query patterns
    $table->index(['status', 'created_at']);
    $table->index(['category_id', 'is_active']);
    
    // Full-text search indexes
    $table->fullText(['name', 'description']);
});
```

#### Query Scoping
```php
// OPTIMIZE: Use query scopes for complex conditions
class Product extends Model
{
    public function scopeActive($query)
    {
        return $query->where('is_active', true)
                    ->where('stock', '>', 0);
    }
    
    public function scopeWithFullDetails($query)
    {
        return $query->with([
            'category',
            'tags',
            'reviews' => fn($q) => $q->latest()->limit(5)
        ]);
    }
}

// In Resource
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->active()
        ->withFullDetails();
}
```

### 2. Table Performance

#### Pagination and Limits
```php
// OPTIMIZE: Use appropriate pagination
public static function table(Table $table): Table
{
    return $table
        ->paginated([10, 25, 50]) // Don't allow 'all'
        ->defaultPaginationPageOption(25)
        ->deferLoading() // Load data only when tab is visible
        ->poll('30s') // Reasonable polling interval
        ->persistSortInSession()
        ->persistFiltersInSession()
        ->persistSearchInSession();
}
```

#### Column Optimization
```php
// OPTIMIZE: Efficient column configuration
TextColumn::make('name')
    ->searchable(isIndividual: true) // Search this column individually
    ->sortable()
    ->limit(50) // Limit text in table

// Use computed columns from database
TextColumn::make('orders_count')
    ->counts('orders') // Let database count

TextColumn::make('total_revenue')
    ->getStateUsing(function ($record) {
        // Use pre-calculated value from database
        return $record->orders_sum_total ?? 0;
    })

// Avoid loading large text fields
TextColumn::make('summary')
    ->getStateUsing(fn ($record) => 
        Str::limit($record->description, 100)
    )
    ->tooltip(fn ($record) => $record->description)
```

#### Lazy Loading Prevention
```php
// OPTIMIZE: Prevent N+1 queries
protected function getTableQuery(): Builder
{
    return parent::getTableQuery()
        ->select('products.*')
        ->selectRaw('
            (SELECT COUNT(*) FROM orders WHERE product_id = products.id) as orders_count,
            (SELECT SUM(total) FROM orders WHERE product_id = products.id) as revenue_total
        ');
}
```

### 3. Caching Strategies

#### Query Result Caching
```php
// OPTIMIZE: Cache expensive queries
public static function getNavigationBadge(): ?string
{
    return Cache::remember(
        key: 'products.pending_count',
        ttl: now()->addMinutes(5),
        callback: fn() => static::getModel()::where('status', 'pending')->count()
    );
}

// Cache with tags for easy invalidation
public static function getGlobalSearchResults(string $search): Collection
{
    return Cache::tags(['products', 'search'])->remember(
        key: "product_search_{$search}",
        ttl: 300,
        callback: fn() => static::getModel()::search($search)->limit(50)->get()
    );
}
```

#### Widget Caching
```php
class ProductStatsWidget extends BaseWidget
{
    protected function getStats(): array
    {
        return Cache::remember('product_stats_' . auth()->id(), 300, function () {
            return [
                Stat::make('Total Products', $this->getTotalProducts())
                    ->chart($this->getProductChart()),
                Stat::make('Revenue', $this->getRevenue())
                    ->description('This month'),
            ];
        });
    }
    
    private function getTotalProducts(): int
    {
        return DB::table('products')
            ->where('team_id', Filament::getTenant()->id)
            ->count();
    }
}
```

#### Cache Invalidation
```php
// OPTIMIZE: Smart cache invalidation
class Product extends Model
{
    protected static function booted()
    {
        static::saved(function () {
            Cache::tags(['products'])->flush();
            Cache::forget('products.pending_count');
        });
        
        static::deleted(function () {
            Cache::tags(['products'])->flush();
        });
    }
}
```

## Frontend Optimization

### 1. Asset Optimization

#### JavaScript and CSS
```php
// OPTIMIZE: Minify and bundle assets
public function register(): void
{
    FilamentAsset::register([
        Js::make('custom-js', 
            app()->environment('production') 
                ? resource_path('js/custom.min.js')
                : resource_path('js/custom.js')
        ),
        Css::make('custom-css',
            app()->environment('production')
                ? resource_path('css/custom.min.css')
                : resource_path('css/custom.css')
        ),
    ], 'app');
}
```

#### Lazy Loading Components
```php
// OPTIMIZE: Load heavy components only when needed
Section::make('Analytics')
    ->schema([
        ViewField::make('analytics')
            ->view('filament.components.analytics-dashboard')
    ])
    ->collapsed() // Start collapsed
    ->persistCollapsed() // Remember state
    ->lazy() // Load content only when expanded
```

### 2. Form Optimization

#### Debouncing Reactive Fields
```php
// OPTIMIZE: Reduce server calls
TextInput::make('search')
    ->reactive()
    ->debounce(500) // Wait 500ms after user stops typing
    ->afterStateUpdated(fn($state) => $this->search($state))
```

#### Conditional Loading
```php
// OPTIMIZE: Load options only when needed
Select::make('subcategory_id')
    ->options(function (callable $get) {
        $categoryId = $get('category_id');
        
        if (!$categoryId) {
            return [];
        }
        
        return Cache::remember(
            "subcategories_{$categoryId}",
            300,
            fn() => Subcategory::where('category_id', $categoryId)
                ->pluck('name', 'id')
        );
    })
    ->searchable()
    ->preload() // Preload all options
```

### 3. File Upload Optimization

```php
// OPTIMIZE: Efficient file handling
FileUpload::make('images')
    ->multiple()
    ->image()
    ->maxSize(2048) // Limit file size
    ->acceptedFileTypes(['image/jpeg', 'image/png', 'image/webp'])
    ->imageResizeMode('cover')
    ->imageResizeTargetWidth('1920')
    ->imageResizeTargetHeight('1080')
    ->imagePreviewHeight('200')
    ->loadingIndicatorPosition('center')
    ->panelLayout('grid')
    ->reorderable()
    ->appendFiles() // Don't reload existing files
    ->storeFileNamesIn('original_filenames')
    ->uploadProgressIndicatorPosition('center')
    ->removeUploadedFileButtonPosition('center')
    ->optimization('webp') // Convert to WebP
    ->responsiveImages() // Generate responsive versions
```

## Server-Side Optimization

### 1. Queue Heavy Operations

```php
// OPTIMIZE: Use queues for heavy tasks
Tables\Actions\Action::make('generate_report')
    ->action(function (Collection $records) {
        GenerateReportJob::dispatch($records->pluck('id'), auth()->user());
        
        Notification::make()
            ->title('Report generation started')
            ->body('You will be notified when the report is ready.')
            ->success()
            ->send();
    })
```

### 2. Chunking Large Operations

```php
// OPTIMIZE: Process large datasets in chunks
Tables\Actions\BulkAction::make('process')
    ->action(function (Collection $records) {
        $records->chunk(100)->each(function ($chunk) {
            ProcessChunkJob::dispatch($chunk->pluck('id'));
        });
    })
```

### 3. Database Connection Pooling

```php
// config/database.php
'mysql' => [
    'driver' => 'mysql',
    'sticky' => true, // OPTIMIZE: Use sticky sessions
    'pool' => [
        'min' => 5,
        'max' => 20,
    ],
],
```

## Memory Optimization

### 1. Streaming Large Exports

```php
// OPTIMIZE: Stream large exports instead of loading in memory
public function export()
{
    return response()->streamDownload(function () {
        $handle = fopen('php://output', 'w');
        
        // Headers
        fputcsv($handle, ['ID', 'Name', 'Price']);
        
        // Stream data in chunks
        Product::query()
            ->select(['id', 'name', 'price'])
            ->chunk(1000, function ($products) use ($handle) {
                foreach ($products as $product) {
                    fputcsv($handle, $product->toArray());
                }
            });
        
        fclose($handle);
    }, 'products.csv');
}
```

### 2. Clearing Memory

```php
// OPTIMIZE: Clear memory in long-running operations
protected function processLargeDataset()
{
    Product::chunk(500, function ($products) {
        foreach ($products as $product) {
            $this->processProduct($product);
        }
        
        // Clear memory
        unset($products);
        
        // Optionally trigger garbage collection
        if (memory_get_usage() > 100 * 1024 * 1024) { // 100MB
            gc_collect_cycles();
        }
    });
}
```

## Monitoring & Profiling

### 1. Query Monitoring

```php
// OPTIMIZE: Monitor slow queries in development
if (app()->environment('local')) {
    DB::listen(function ($query) {
        if ($query->time > 100) { // Log queries over 100ms
            Log::warning('Slow query detected', [
                'sql' => $query->sql,
                'bindings' => $query->bindings,
                'time' => $query->time,
            ]);
        }
    });
}
```

### 2. Performance Metrics

```php
// OPTIMIZE: Track performance metrics
class PerformanceMiddleware
{
    public function handle($request, Closure $next)
    {
        $start = microtime(true);
        
        $response = $next($request);
        
        $duration = microtime(true) - $start;
        
        if ($duration > 1) { // Log requests over 1 second
            Log::warning('Slow request', [
                'uri' => $request->getUri(),
                'duration' => $duration,
                'memory' => memory_get_peak_usage(true) / 1024 / 1024 . 'MB',
            ]);
        }
        
        return $response;
    }
}
```

## Optimization Checklist

### Database
- [ ] Add indexes for searchable/sortable columns
- [ ] Use eager loading for relationships
- [ ] Implement query result caching
- [ ] Use database views for complex queries
- [ ] Enable query caching in MySQL/PostgreSQL
- [ ] Optimize database configuration (buffer pool, connections)

### Tables
- [ ] Enable pagination (avoid loading all records)
- [ ] Use deferred loading for tabs
- [ ] Limit text columns with `->limit()`
- [ ] Cache table filters and searches in session
- [ ] Use database aggregations instead of PHP

### Forms
- [ ] Debounce reactive fields
- [ ] Lazy load heavy components
- [ ] Cache select options
- [ ] Use conditional field loading
- [ ] Optimize file uploads with size/type limits

### Caching
- [ ] Cache navigation badges
- [ ] Cache widget data
- [ ] Cache expensive computations
- [ ] Use Redis/Memcached in production
- [ ] Implement cache warming strategies

### Assets
- [ ] Minify CSS and JavaScript
- [ ] Enable Gzip compression
- [ ] Use CDN for static assets
- [ ] Implement browser caching headers
- [ ] Optimize images (WebP, lazy loading)

### Server
- [ ] Configure PHP OPcache
- [ ] Use PHP-FPM with proper pool configuration
- [ ] Enable HTTP/2
- [ ] Configure nginx/Apache caching
- [ ] Use queue workers for heavy operations

### Monitoring
- [ ] Set up application monitoring (New Relic, DataDog)
- [ ] Monitor database slow queries
- [ ] Track memory usage
- [ ] Set up alerts for performance degradation
- [ ] Regular performance audits

## Performance Benchmarks

### Target Metrics
- Page load time: < 500ms
- Table load time: < 300ms
- Form submission: < 200ms
- File upload (per MB): < 2s
- Search response: < 100ms
- Memory usage per request: < 128MB
- Database queries per request: < 20
