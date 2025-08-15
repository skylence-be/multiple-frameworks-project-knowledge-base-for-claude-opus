# Filament 4 Advanced Patterns & Best Practices

## Architecture Patterns

### Service Layer Pattern

```php
// app/Services/ProductService.php
namespace App\Services;

use App\Models\Product;
use Illuminate\Support\Collection;

class ProductService
{
    public function createProduct(array $data): Product
    {
        return DB::transaction(function () use ($data) {
            $product = Product::create($data);
            
            if (isset($data['categories'])) {
                $product->categories()->sync($data['categories']);
            }
            
            if (isset($data['images'])) {
                $this->attachImages($product, $data['images']);
            }
            
            event(new ProductCreated($product));
            
            return $product;
        });
    }
    
    public function updateStock(Product $product, int $quantity): void
    {
        $product->increment('stock', $quantity);
        
        if ($product->stock > 0 && $product->wasOutOfStock()) {
            Notification::make()
                ->title('Product back in stock')
                ->body("{$product->name} is now available")
                ->success()
                ->sendToDatabase(User::role('admin')->get());
        }
    }
}

// In ProductResource
protected function mutateFormDataBeforeCreate(array $data): array
{
    return app(ProductService::class)->prepareData($data);
}
```

### Repository Pattern

```php
// app/Repositories/ProductRepository.php
namespace App\Repositories;

use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;

class ProductRepository
{
    public function getActiveProducts(): Builder
    {
        return Product::query()
            ->where('is_active', true)
            ->where('stock', '>', 0);
    }
    
    public function getLowStockProducts(int $threshold = 10): Builder
    {
        return Product::query()
            ->where('stock', '<', $threshold)
            ->where('stock', '>', 0);
    }
    
    public function searchProducts(string $query): Builder
    {
        return Product::query()
            ->where(function ($q) use ($query) {
                $q->where('name', 'like', "%{$query}%")
                  ->orWhere('description', 'like', "%{$query}%")
                  ->orWhere('sku', 'like', "%{$query}%");
            });
    }
}

// In Resource
public static function getEloquentQuery(): Builder
{
    return app(ProductRepository::class)->getActiveProducts();
}
```

### Action Classes

```php
// app/Filament/Actions/ExportProductsAction.php
namespace App\Filament\Actions;

use Filament\Tables\Actions\Action;
use Maatwebsite\Excel\Facades\Excel;

class ExportProductsAction
{
    public static function make(): Action
    {
        return Action::make('export')
            ->label('Export to Excel')
            ->icon('heroicon-o-arrow-down-tray')
            ->form([
                DatePicker::make('from_date'),
                DatePicker::make('to_date'),
                Select::make('format')
                    ->options([
                        'xlsx' => 'Excel',
                        'csv' => 'CSV',
                        'pdf' => 'PDF',
                    ])
                    ->default('xlsx'),
            ])
            ->action(function (array $data) {
                return Excel::download(
                    new ProductsExport($data),
                    'products.' . $data['format']
                );
            });
    }
}

// Usage in Resource
->headerActions([
    ExportProductsAction::make(),
])
```

## Performance Optimization

### Query Optimization

```php
// Eager Loading
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->with(['category', 'tags', 'media'])
        ->withCount(['orders', 'reviews'])
        ->withAvg('reviews', 'rating');
}

// Lazy Loading Prevention
public static function table(Table $table): Table
{
    return $table
        ->columns([
            TextColumn::make('category.name')
                ->label('Category'),
            TextColumn::make('orders_count')
                ->label('Orders'),
            TextColumn::make('reviews_avg_rating')
                ->label('Rating')
                ->formatStateUsing(fn ($state) => number_format($state, 1)),
        ])
        ->modifyQueryUsing(fn (Builder $query) => $query->with('category'));
}
```

### Caching Strategies

```php
// Cache expensive computations
public static function getNavigationBadge(): ?string
{
    return Cache::remember('products.low_stock_count', 300, function () {
        return Product::where('stock', '<', 10)->count();
    });
}

// Clear cache on updates
protected function afterSave(): void
{
    Cache::forget('products.low_stock_count');
    Cache::tags(['products'])->flush();
}

// Widget caching
class ProductStatsWidget extends BaseWidget
{
    protected static ?string $pollingInterval = '30s';
    
    protected function getStats(): array
    {
        return Cache::remember('product_stats', 60, function () {
            return [
                Stat::make('Total Revenue', Product::sum('price'))
                    ->description('All time'),
                Stat::make('Average Price', Product::avg('price'))
                    ->description('Per product'),
            ];
        });
    }
}
```

### Chunking Large Datasets

```php
// Bulk operations with chunking
Tables\Actions\BulkAction::make('updatePrices')
    ->action(function (Collection $records, array $data) {
        $records->chunk(100)->each(function ($chunk) use ($data) {
            DB::transaction(function () use ($chunk, $data) {
                $chunk->each(function ($record) use ($data) {
                    $record->update([
                        'price' => $record->price * (1 + $data['percentage'] / 100)
                    ]);
                });
            });
        });
    })
```

## Security Patterns

### Authorization

```php
// Resource-level authorization
public static function canViewAny(): bool
{
    return auth()->user()->can('view_any_products');
}

public static function canCreate(): bool
{
    return auth()->user()->can('create_products');
}

// Field-level authorization
TextInput::make('cost_price')
    ->visible(fn () => auth()->user()->hasRole('admin'))
    ->disabled(fn () => !auth()->user()->can('edit_cost_price'))

// Action authorization
Tables\Actions\DeleteAction::make()
    ->authorize(fn (Product $record) => 
        auth()->user()->can('delete', $record)
    )
```

### Data Validation & Sanitization

```php
// Custom validation rules
TextInput::make('sku')
    ->rules([
        'required',
        'string',
        'max:50',
        new UniqueSkuRule(),
        function () {
            return function (string $attribute, $value, Closure $fail) {
                if (!preg_match('/^[A-Z0-9-]+$/', $value)) {
                    $fail('SKU must contain only uppercase letters, numbers, and hyphens.');
                }
            };
        },
    ])

// Data sanitization
protected function mutateFormDataBeforeSave(array $data): array
{
    $data['description'] = strip_tags($data['description'], '<p><br><strong><em>');
    $data['price'] = round($data['price'], 2);
    $data['slug'] = Str::slug($data['name']);
    
    return $data;
}
```

### Audit Logging

```php
// Activity logging trait
trait LogsActivity
{
    public static function bootLogsActivity()
    {
        static::created(function ($model) {
            activity()
                ->performedOn($model)
                ->causedBy(auth()->user())
                ->log('created');
        });
        
        static::updated(function ($model) {
            activity()
                ->performedOn($model)
                ->causedBy(auth()->user())
                ->withProperties(['old' => $model->getOriginal()])
                ->log('updated');
        });
    }
}

// In Model
class Product extends Model
{
    use LogsActivity;
    
    protected static $logAttributes = ['name', 'price', 'stock'];
    protected static $logOnlyDirty = true;
}
```

## Testing Patterns

### Resource Testing

```php
// tests/Feature/Filament/ProductResourceTest.php
use App\Filament\Resources\ProductResource;
use App\Models\Product;
use Filament\Actions\DeleteAction;
use Livewire\Livewire;

class ProductResourceTest extends TestCase
{
    public function test_can_list_products()
    {
        $products = Product::factory()->count(10)->create();
        
        Livewire::test(ProductResource\Pages\ListProducts::class)
            ->assertCanSeeTableRecords($products);
    }
    
    public function test_can_create_product()
    {
        Livewire::test(ProductResource\Pages\CreateProduct::class)
            ->fillForm([
                'name' => 'Test Product',
                'price' => 99.99,
                'stock' => 100,
            ])
            ->call('create')
            ->assertHasNoFormErrors();
        
        $this->assertDatabaseHas('products', [
            'name' => 'Test Product',
            'price' => 99.99,
        ]);
    }
    
    public function test_can_validate_product()
    {
        Livewire::test(ProductResource\Pages\CreateProduct::class)
            ->fillForm([
                'name' => '',
                'price' => -10,
            ])
            ->call('create')
            ->assertHasFormErrors([
                'name' => 'required',
                'price' => 'min',
            ]);
    }
}
```

### Widget Testing

```php
public function test_product_stats_widget_displays_correct_data()
{
    Product::factory()->count(5)->create(['price' => 100]);
    
    Livewire::test(ProductStatsWidget::class)
        ->assertSee('500') // Total
        ->assertSee('100'); // Average
}
```

## Multi-tenancy Patterns

### Team-based Tenancy

```php
// In Model
use Filament\Facades\Filament;

class Product extends Model
{
    protected static function booted()
    {
        static::creating(function ($product) {
            if (Filament::getTenant()) {
                $product->team_id = Filament::getTenant()->id;
            }
        });
        
        static::addGlobalScope('team', function (Builder $builder) {
            if (Filament::getTenant()) {
                $builder->where('team_id', Filament::getTenant()->id);
            }
        });
    }
}

// In Panel Provider
public function panel(Panel $panel): Panel
{
    return $panel
        ->tenant(Team::class)
        ->tenantBillingProvider(new StripeBillingProvider())
        ->tenantMenuItems([
            MenuItem::make()
                ->label('Settings')
                ->url(fn () => TeamSettings::getUrl())
                ->icon('heroicon-o-cog-6-tooth'),
        ]);
}
```

## Custom Field Patterns

### Composite Fields

```php
// app/Forms/Components/AddressInput.php
class AddressInput extends Field
{
    protected string $view = 'forms.components.address-input';
    
    public function setUp(): void
    {
        parent::setUp();
        
        $this->schema([
            TextInput::make('street')->required(),
            Grid::make(3)
                ->schema([
                    TextInput::make('city')->required(),
                    TextInput::make('state')->required(),
                    TextInput::make('zip')->required(),
                ]),
        ]);
    }
}

// Usage
AddressInput::make('billing_address')
    ->label('Billing Address')
```

### Macro Extensions

```php
// In Service Provider
TextInput::macro('money', function (string $currency = 'USD') {
    return $this
        ->numeric()
        ->prefix($currency === 'USD' ? '$' : '€')
        ->mask(fn (Mask $mask) => $mask
            ->numeric()
            ->decimalPlaces(2)
            ->decimalSeparator('.')
            ->thousandsSeparator(',')
        );
});

// Usage
TextInput::make('price')->money('USD')
```

## Integration Patterns

### External API Integration

```php
// app/Filament/Resources/ProductResource.php
Select::make('external_product_id')
    ->searchable()
    ->getSearchResultsUsing(function (string $search) {
        return Http::get('https://api.example.com/products', [
            'search' => $search,
        ])->json('data')
          ->mapWithKeys(fn ($product) => [
              $product['id'] => $product['name']
          ]);
    })
    ->getOptionLabelUsing(function ($value) {
        $product = Cache::remember("product.{$value}", 3600, function () use ($value) {
            return Http::get("https://api.example.com/products/{$value}")->json();
        });
        
        return $product['name'] ?? 'Unknown';
    })
```

### Webhook Processing

```php
// After resource actions
protected function afterCreate(): void
{
    dispatch(new SendWebhook('product.created', $this->record));
}

// Job
class SendWebhook implements ShouldQueue
{
    public function handle()
    {
        Http::post(config('services.webhook.url'), [
            'event' => $this->event,
            'data' => $this->data,
            'timestamp' => now()->toIso8601String(),
        ]);
    }
}
```

## UI/UX Patterns

### Progressive Disclosure

```php
// Show advanced options only when needed
Toggle::make('has_variants')
    ->reactive()

Section::make('Variants')
    ->schema([
        Repeater::make('variants')
            ->schema([
                TextInput::make('name'),
                TextInput::make('sku'),
                TextInput::make('price')->numeric(),
            ])
    ])
    ->visible(fn (Get $get) => $get('has_variants'))
    ->collapsed()
```

### Contextual Help

```php
TextInput::make('tax_rate')
    ->suffix('%')
    ->helperText('Enter the tax rate as a percentage')
    ->hint('[Tax Calculator](https://example.com/tax-calculator)')
    ->hintIcon('heroicon-o-question-mark-circle')
    ->hintColor('primary')
```

### Wizard with Validation

```php
Wizard::make([
    Step::make('Product Details')
        ->schema([...])
        ->beforeValidation(function () {
            // Custom validation logic
        }),
    Step::make('Pricing')
        ->schema([...])
        ->visible(fn (Get $get) => $get('type') !== 'free'),
    Step::make('Inventory')
        ->schema([...])
        ->afterValidation(function () {
            // Post-validation logic
        }),
])
->submitAction(new HtmlString(
    '<button type="submit">Create Product</button>'
))
```
