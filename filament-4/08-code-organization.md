# Filament v4 Code Organization

## Project Structure

### 1. Standard Filament Structure

```
app/
├── Filament/
│   ├── Clusters/                    # Group related resources
│   │   ├── Products/
│   │   │   ├── Resources/
│   │   │   │   ├── ProductResource.php
│   │   │   │   └── CategoryResource.php
│   │   │   └── ProductsCluster.php
│   │   └── Settings/
│   │       ├── Pages/
│   │       │   ├── GeneralSettings.php
│   │       │   └── EmailSettings.php
│   │       └── SettingsCluster.php
│   ├── Resources/
│   │   ├── ProductResource.php
│   │   └── ProductResource/
│   │       ├── Pages/
│   │       │   ├── CreateProduct.php
│   │       │   ├── EditProduct.php
│   │       │   ├── ListProducts.php
│   │       │   └── ViewProduct.php
│   │       ├── RelationManagers/
│   │       │   ├── CategoriesRelationManager.php
│   │       │   ├── ReviewsRelationManager.php
│   │       │   └── VariantsRelationManager.php
│   │       └── Widgets/
│   │           ├── ProductStats.php
│   │           └── ProductChart.php
│   ├── Pages/
│   │   ├── Dashboard.php
│   │   ├── Settings.php
│   │   └── Reports/
│   │       ├── SalesReport.php
│   │       └── InventoryReport.php
│   ├── Widgets/
│   │   ├── StatsOverviewWidget.php
│   │   ├── RecentOrdersWidget.php
│   │   └── RevenueChartWidget.php
│   ├── Actions/
│   │   ├── ExportAction.php
│   │   ├── ImportAction.php
│   │   └── BulkUpdateAction.php
│   ├── Forms/
│   │   ├── Components/
│   │   │   ├── AddressInput.php
│   │   │   ├── MoneyInput.php
│   │   │   └── ColorPicker.php
│   │   └── Concerns/
│   │       ├── HasAddress.php
│   │       └── HasMoney.php
│   ├── Tables/
│   │   ├── Columns/
│   │   │   ├── StatusColumn.php
│   │   │   └── ProgressColumn.php
│   │   ├── Filters/
│   │   │   ├── DateRangeFilter.php
│   │   │   └── PriceRangeFilter.php
│   │   └── Actions/
│   │       ├── ReplicateAction.php
│   │       └── ArchiveAction.php
│   ├── Exports/
│   │   ├── ProductsExport.php
│   │   └── OrdersExport.php
│   └── Imports/
│       ├── ProductsImport.php
│       └── CustomersImport.php
├── Models/
│   ├── Product.php
│   ├── Category.php
│   └── Traits/
│       ├── HasStatus.php
│       └── Auditable.php
├── Services/
│   ├── ProductService.php
│   ├── OrderService.php
│   └── NotificationService.php
├── Repositories/
│   ├── ProductRepository.php
│   └── OrderRepository.php
├── Policies/
│   ├── ProductPolicy.php
│   └── CategoryPolicy.php
├── Observers/
│   ├── ProductObserver.php
│   └── OrderObserver.php
└── Providers/
    └── Filament/
        ├── AdminPanelProvider.php
        └── CustomerPanelProvider.php
```

### 2. Domain-Driven Design Structure

```
app/
├── Domain/
│   ├── Product/
│   │   ├── Models/
│   │   │   ├── Product.php
│   │   │   └── ProductVariant.php
│   │   ├── Actions/
│   │   │   ├── CreateProductAction.php
│   │   │   └── UpdateInventoryAction.php
│   │   ├── Data/
│   │   │   ├── ProductData.php
│   │   │   └── VariantData.php
│   │   ├── Enums/
│   │   │   ├── ProductStatus.php
│   │   │   └── StockStatus.php
│   │   ├── Events/
│   │   │   ├── ProductCreated.php
│   │   │   └── StockDepleted.php
│   │   ├── QueryBuilders/
│   │   │   └── ProductQueryBuilder.php
│   │   └── Rules/
│   │       ├── ValidSku.php
│   │       └── UniqueProductName.php
│   ├── Order/
│   │   ├── Models/
│   │   ├── Actions/
│   │   └── Services/
│   └── Customer/
│       ├── Models/
│       ├── Actions/
│       └── Services/
├── Application/
│   ├── Admin/
│   │   └── Filament/
│   │       ├── Resources/
│   │       └── Pages/
│   └── Api/
│       └── Controllers/
└── Infrastructure/
    ├── Persistence/
    │   └── Repositories/
    └── External/
        └── Services/
```

### 3. Modular Structure

```
app/
├── Modules/
│   ├── Product/
│   │   ├── Filament/
│   │   │   ├── Resources/
│   │   │   └── Pages/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── Http/
│   │   │   └── Controllers/
│   │   ├── Database/
│   │   │   ├── Migrations/
│   │   │   └── Seeders/
│   │   └── module.json
│   ├── Order/
│   │   └── ...
│   └── Customer/
│       └── ...
└── Core/
    ├── Filament/
    │   ├── Components/
    │   └── Traits/
    └── Traits/
```

## Resource Organization

### 1. Base Resource Class

```php
// app/Filament/Resources/BaseResource.php
namespace App\Filament\Resources;

use Filament\Resources\Resource;
use Illuminate\Database\Eloquent\Builder;

abstract class BaseResource extends Resource
{
    protected static ?int $navigationSort = 999;
    
    public static function getGlobalSearchEloquentQuery(): Builder
    {
        return parent::getGlobalSearchEloquentQuery()
            ->with(['team']);
    }
    
    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->when(
                static::shouldApplyTenancy(),
                fn (Builder $query) => $query->whereBelongsTo(Filament::getTenant())
            );
    }
    
    protected static function shouldApplyTenancy(): bool
    {
        return true;
    }
}
```

### 2. Resource Traits

```php
// app/Filament/Resources/Concerns/HasBulkActions.php
namespace App\Filament\Resources\Concerns;

trait HasBulkActions
{
    public static function getBulkActions(): array
    {
        return [
            Tables\Actions\BulkAction::make('export')
                ->action(fn (Collection $records) => static::exportRecords($records))
                ->icon('heroicon-o-arrow-down-tray'),
                
            Tables\Actions\DeleteBulkAction::make()
                ->requiresConfirmation(),
        ];
    }
    
    protected static function exportRecords(Collection $records): mixed
    {
        return Excel::download(
            new static::$exportClass($records),
            static::getPluralModelLabel() . '.xlsx'
        );
    }
}
```

### 3. Grouped Resources

```php
// app/Filament/Resources/Shop/ProductResource.php
namespace App\Filament\Resources\Shop;

class ProductResource extends BaseResource
{
    protected static ?string $navigationGroup = 'Shop';
    protected static ?string $navigationIcon = 'heroicon-o-shopping-bag';
    protected static ?int $navigationSort = 1;
    
    public static function getNavigationBadge(): ?string
    {
        return cache()->remember(
            'products.count',
            now()->addMinutes(5),
            fn () => static::getModel()::count()
        );
    }
}
```

## Component Organization

### 1. Custom Form Components

```php
// app/Filament/Forms/Components/AddressInput.php
namespace App\Filament\Forms\Components;

use Filament\Forms\Components\Field;

class AddressInput extends Field
{
    protected string $view = 'filament.forms.components.address-input';
    
    public function setUp(): void
    {
        parent::setUp();
        
        $this->columnSpan('full');
        
        $this->afterStateHydrated(function (AddressInput $component, ?array $state) {
            $component->state($state ?? [
                'street' => '',
                'city' => '',
                'state' => '',
                'zip' => '',
                'country' => '',
            ]);
        });
    }
}
```

### 2. Custom Table Columns

```php
// app/Filament/Tables/Columns/StatusColumn.php
namespace App\Filament\Tables\Columns;

use Filament\Tables\Columns\Column;

class StatusColumn extends Column
{
    protected string $view = 'filament.tables.columns.status-column';
    
    public function getColor(): string
    {
        return match($this->getState()) {
            'active' => 'success',
            'pending' => 'warning',
            'inactive' => 'danger',
            default => 'secondary',
        };
    }
}
```

## Service Layer Organization

### 1. Service Classes

```php
// app/Services/ProductService.php
namespace App\Services;

use App\Models\Product;
use App\Data\ProductData;
use Illuminate\Support\Facades\DB;

class ProductService
{
    public function __construct(
        private ProductRepository $repository,
        private InventoryService $inventory,
        private NotificationService $notifications
    ) {}
    
    public function create(ProductData $data): Product
    {
        return DB::transaction(function () use ($data) {
            $product = $this->repository->create($data->toArray());
            
            if ($data->has_variants) {
                $this->createVariants($product, $data->variants);
            }
            
            $this->inventory->initializeStock($product);
            $this->notifications->notifyProductCreated($product);
            
            return $product;
        });
    }
}
```

### 2. Action Classes

```php
// app/Actions/Product/CreateProductAction.php
namespace App\Actions\Product;

use App\Models\Product;
use App\Data\ProductData;

class CreateProductAction
{
    public function execute(ProductData $data): Product
    {
        $product = Product::create($data->except('variants')->toArray());
        
        if ($data->variants) {
            $product->variants()->createMany($data->variants);
        }
        
        event(new ProductCreated($product));
        
        return $product->load('variants');
    }
}
```

## Configuration Management

### 1. Resource Configuration

```php
// config/filament-resources.php
return [
    'defaults' => [
        'per_page' => 25,
        'max_per_page' => 100,
        'enable_global_search' => true,
        'enable_soft_deletes' => true,
    ],
    
    'resources' => [
        'products' => [
            'enable_import' => true,
            'enable_export' => true,
            'searchable_columns' => ['name', 'sku', 'description'],
            'filterable_columns' => ['status', 'category_id', 'price'],
        ],
    ],
];
```

### 2. Panel Configuration

```php
// app/Providers/Filament/AdminPanelProvider.php
class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\\Filament\\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\\Filament\\Pages')
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\\Filament\\Widgets')
            ->discoverClusters(in: app_path('Filament/Clusters'), for: 'App\\Filament\\Clusters')
            ->resources($this->getResources())
            ->pages($this->getPages())
            ->widgets($this->getWidgets())
            ->middleware($this->getMiddleware())
            ->authMiddleware($this->getAuthMiddleware());
    }
    
    protected function getResources(): array
    {
        return config('filament.resources', []);
    }
}
```

## Best Practices for Organization

### 1. Single Responsibility
- Each class should have one reason to change
- Resources handle UI, Services handle business logic
- Models handle data and relationships

### 2. Consistent Naming
```php
// Resources: Singular with "Resource" suffix
ProductResource.php
CategoryResource.php

// Pages: Action-based naming
CreateProduct.php
EditProduct.php
ListProducts.php

// Widgets: Descriptive with "Widget" suffix
ProductStatsWidget.php
RevenueChartWidget.php

// Actions: Verb + Noun + "Action"
ExportProductsAction.php
UpdateInventoryAction.php
```

### 3. Trait Usage
```php
// app/Filament/Resources/Concerns/InteractsWithStatus.php
trait InteractsWithStatus
{
    public static function getStatusOptions(): array
    {
        return [
            'active' => 'Active',
            'inactive' => 'Inactive',
            'pending' => 'Pending',
        ];
    }
    
    public static function getStatusColors(): array
    {
        return [
            'active' => 'success',
            'inactive' => 'danger',
            'pending' => 'warning',
        ];
    }
}
```

### 4. Configuration Files
```
config/
├── filament.php           # General Filament config
├── filament-panels.php    # Panel-specific config
├── filament-resources.php # Resource defaults
└── filament-widgets.php   # Widget configuration
```

### 5. View Organization
```
resources/views/
├── filament/
│   ├── components/
│   │   ├── forms/
│   │   └── tables/
│   ├── pages/
│   ├── widgets/
│   └── resources/
│       └── product/
│           └── pages/
```

## Dependency Management

### 1. Service Providers

```php
// app/Providers/FilamentServiceProvider.php
class FilamentServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(ProductService::class, function ($app) {
            return new ProductService(
                $app->make(ProductRepository::class),
                $app->make(InventoryService::class)
            );
        });
    }
    
    public function boot(): void
    {
        Filament::serving(function () {
            Filament::registerScripts([
                asset('js/custom.js'),
            ]);
            
            Filament::registerStyles([
                asset('css/custom.css'),
            ]);
        });
    }
}
```

### 2. Auto-discovery

```json
// composer.json
{
    "extra": {
        "laravel": {
            "providers": [
                "App\\Providers\\FilamentServiceProvider"
            ]
        }
    },
    "autoload": {
        "psr-4": {
            "App\\": "app/",
            "App\\Filament\\": "app/Filament/",
            "App\\Domain\\": "app/Domain/"
        }
    }
}
```
