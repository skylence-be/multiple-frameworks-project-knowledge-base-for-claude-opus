# Filament v4 Best Practices

## General Filament Best Practices

### 1. Resource Organization
```php
// GOOD: Organized resource structure
app/
├── Filament/
│   ├── Resources/
│   │   ├── ProductResource.php
│   │   └── ProductResource/
│   │       ├── Pages/
│   │       │   ├── CreateProduct.php
│   │       │   ├── EditProduct.php
│   │       │   └── ListProducts.php
│   │       ├── RelationManagers/
│   │       │   └── CategoriesRelationManager.php
│   │       └── Widgets/
│   │           └── ProductStats.php
│   ├── Pages/
│   │   └── Dashboard.php
│   └── Widgets/
│       └── StatsOverview.php
```

### 2. Query Optimization
```php
// GOOD: Eager load relationships
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->with(['category', 'tags', 'media'])
        ->withCount(['orders', 'reviews'])
        ->withAvg('reviews', 'rating');
}

// GOOD: Use select to limit columns
public static function table(Table $table): Table
{
    return $table
        ->query(fn () => Product::select(['id', 'name', 'price', 'category_id']))
        ->columns([/* ... */]);
}
```

### 3. Form Validation
```php
// GOOD: Comprehensive validation
TextInput::make('email')
    ->required()
    ->email()
    ->unique(ignoreRecord: true)
    ->maxLength(255)
    ->rules([
        'required',
        'email:rfc,dns',
        new CorporateEmailRule(),
    ])
    ->validationMessages([
        'unique' => 'This email is already registered.',
        'email' => 'Please enter a valid email address.',
    ])
```

### 4. Authorization Best Practices
```php
// GOOD: Use policies for all authorization
class ProductResource extends Resource
{
    public static function canViewAny(): bool
    {
        return auth()->user()->can('viewAny', Product::class);
    }

    public static function canCreate(): bool
    {
        return auth()->user()->can('create', Product::class);
    }
}

// GOOD: Field-level authorization
TextInput::make('cost_price')
    ->visible(fn () => auth()->user()->hasPermission('view_cost_prices'))
    ->disabled(fn () => !auth()->user()->hasPermission('edit_cost_prices'))
```

### 5. State Management
```php
// GOOD: Use reactive fields properly
Select::make('country')
    ->reactive()
    ->afterStateUpdated(fn (callable $set) => $set('state', null))

Select::make('state')
    ->options(fn (Get $get) => 
        $get('country') 
            ? Country::find($get('country'))?->states ?? []
            : []
    )

// GOOD: Use state path for nested data
TextInput::make('address.street')
    ->statePath('billing_address.street')
```

### 6. Action Implementation
```php
// GOOD: Comprehensive action with authorization and confirmation
Tables\Actions\Action::make('approve')
    ->icon('heroicon-o-check-circle')
    ->color('success')
    ->requiresConfirmation()
    ->modalHeading('Approve Product')
    ->modalDescription('Are you sure you want to approve this product?')
    ->modalSubmitActionLabel('Yes, approve')
    ->action(function (Product $record) {
        $record->approve();
        
        Notification::make()
            ->title('Product approved')
            ->success()
            ->send();
    })
    ->visible(fn (Product $record): bool => $record->isPending())
    ->authorize('approve')
```

### 7. Notification Patterns
```php
// GOOD: Informative notifications with actions
Notification::make()
    ->title('Import completed')
    ->body('Successfully imported 150 products.')
    ->success()
    ->persistent()
    ->actions([
        Action::make('view')
            ->button()
            ->url(ProductResource::getUrl('index')),
    ])
    ->sendToDatabase(auth()->user());
```

### 8. Caching Strategy
```php
// GOOD: Cache expensive operations
public static function getNavigationBadge(): ?string
{
    return Cache::remember(
        'products.pending_count',
        now()->addMinutes(5),
        fn () => static::getModel()::pending()->count()
    );
}

// GOOD: Clear cache after mutations
protected function afterSave(): void
{
    Cache::forget('products.pending_count');
    Cache::tags(['products'])->flush();
}
```

### 9. File Upload Configuration
```php
// GOOD: Comprehensive file upload setup
FileUpload::make('images')
    ->multiple()
    ->image()
    ->imageEditor()
    ->imageEditorAspectRatios([
        '16:9',
        '4:3',
        '1:1',
    ])
    ->directory('products')
    ->disk('s3')
    ->visibility('public')
    ->maxSize(5120) // 5MB
    ->maxFiles(10)
    ->acceptedFileTypes(['image/jpeg', 'image/png', 'image/webp'])
    ->imageResizeMode('cover')
    ->imageCropAspectRatio('16:9')
    ->imageResizeTargetWidth('1920')
    ->imageResizeTargetHeight('1080')
    ->moveFiles() // Move instead of copy
    ->storeFileNamesIn('original_filenames')
```

### 10. Table Features
```php
// GOOD: Comprehensive table configuration
public static function table(Table $table): Table
{
    return $table
        ->columns([/* ... */])
        ->defaultSort('created_at', 'desc')
        ->persistSortInSession()
        ->persistSearchInSession()
        ->persistFiltersInSession()
        ->striped()
        ->poll('10s')
        ->deferLoading() // Load data only when needed
        ->paginationPageOptions([10, 25, 50, 100])
        ->extremePaginationLinks()
        ->recordUrl(
            fn (Model $record): string => 
                static::getUrl('edit', ['record' => $record])
        );
}
```

### 11. Multi-tenancy Setup
```php
// GOOD: Proper tenant configuration
public function panel(Panel $panel): Panel
{
    return $panel
        ->tenant(Team::class)
        ->tenantOwnershipRelationshipName('owner')
        ->tenantBillingProvider(new StripeBillingProvider())
        ->tenantRegistration(RegisterTeam::class)
        ->tenantProfile(EditTeamProfile::class)
        ->tenantMenuItems([
            'billing' => MenuItem::make()
                ->label('Billing')
                ->icon('heroicon-o-credit-card')
                ->url(fn (): string => TeamBilling::getUrl()),
        ]);
}

// GOOD: Apply tenant scope in models
protected static function booted(): void
{
    static::creating(function (Model $model) {
        $model->team_id = Filament::getTenant()->id;
    });
    
    static::addGlobalScope('team', function (Builder $query) {
        $query->whereBelongsTo(Filament::getTenant());
    });
}
```

### 12. Custom Field Creation
```php
// GOOD: Reusable custom field
class MoneyInput extends TextInput
{
    protected function setUp(): void
    {
        parent::setUp();
        
        $this
            ->prefix('$')
            ->numeric()
            ->mask(fn (Mask $mask) => $mask
                ->numeric()
                ->decimalPlaces(2)
                ->decimalSeparator('.')
                ->thousandsSeparator(',')
                ->minValue(0)
            )
            ->step(0.01);
    }
    
    public function currency(string $currency): static
    {
        return $this->prefix($currency);
    }
}
```

### 13. Testing Best Practices
```php
// GOOD: Comprehensive resource testing
public function test_can_create_product_with_validation()
{
    $user = User::factory()->admin()->create();
    
    Livewire::actingAs($user)
        ->test(CreateProduct::class)
        ->fillForm([
            'name' => 'Test Product',
            'price' => 99.99,
            'category_id' => Category::factory()->create()->id,
        ])
        ->call('create')
        ->assertHasNoFormErrors()
        ->assertRedirect(ProductResource::getUrl('index'));
    
    $this->assertDatabaseHas('products', [
        'name' => 'Test Product',
        'price' => 99.99,
    ]);
}
```

### 14. Widget Implementation
```php
// GOOD: Optimized widget with caching
class ProductStatsWidget extends BaseWidget
{
    protected static ?int $sort = 1;
    protected static ?string $pollingInterval = '30s';
    protected int | string | array $columnSpan = 'full';
    
    protected function getStats(): array
    {
        return Cache::remember('product_stats', 300, function () {
            return [
                Stat::make(
                    'Total Products',
                    Product::count()
                )
                ->description('All time')
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->chart([7, 2, 10, 3, 15, 4, 17])
                ->color('success'),
            ];
        });
    }
}
```

### 15. Bulk Operations
```php
// GOOD: Efficient bulk operations with chunking
Tables\Actions\BulkAction::make('updatePrices')
    ->requiresConfirmation()
    ->form([
        TextInput::make('percentage')
            ->label('Price increase (%)')
            ->numeric()
            ->required()
            ->minValue(-50)
            ->maxValue(100),
    ])
    ->action(function (Collection $records, array $data) {
        $updated = 0;
        
        $records->chunk(100)->each(function ($chunk) use ($data, &$updated) {
            DB::transaction(function () use ($chunk, $data, &$updated) {
                foreach ($chunk as $record) {
                    $record->increment('price', $record->price * ($data['percentage'] / 100));
                    $updated++;
                }
            });
        });
        
        Notification::make()
            ->title("Updated {$updated} products")
            ->success()
            ->send();
    })
    ->deselectRecordsAfterCompletion()
```

## Performance Best Practices

### 1. Database Query Optimization
```php
// GOOD: Use database aggregations
TextColumn::make('orders_count')
    ->counts('orders')
    ->label('Total Orders')

// GOOD: Avoid N+1 queries
->modifyQueryUsing(fn (Builder $query) => 
    $query->with(['category:id,name', 'tags:id,name'])
)

// GOOD: Use indexes
Schema::table('products', function (Blueprint $table) {
    $table->index(['status', 'created_at']);
    $table->index('category_id');
});
```

### 2. Asset Optimization
```php
// GOOD: Optimize assets for production
public function boot(): void
{
    if (app()->environment('production')) {
        FilamentAsset::register([
            Js::make('custom-js', resource_path('js/custom.min.js')),
            Css::make('custom-css', resource_path('css/custom.min.css')),
        ]);
    }
}
```

### 3. Pagination and Limits
```php
// GOOD: Use appropriate pagination
->paginated([10, 25, 50, 100])
->defaultPaginationPageOption(25)

// GOOD: Limit select options
Select::make('user_id')
    ->searchable()
    ->getSearchResultsUsing(fn (string $search) => 
        User::where('name', 'like', "%{$search}%")
            ->limit(50)
            ->pluck('name', 'id')
    )
```

## Security Best Practices

### 1. Input Sanitization
```php
// GOOD: Sanitize HTML content
RichEditor::make('content')
    ->disableToolbarButtons([
        'attachFiles',
        'codeBlock',
    ])
    ->extraInputAttributes(['data-max-length' => 5000])
    ->dehydrateStateUsing(fn ($state) => 
        strip_tags($state, '<p><br><strong><em><ul><ol><li>')
    )
```

### 2. File Security
```php
// GOOD: Validate file uploads thoroughly
FileUpload::make('document')
    ->acceptedFileTypes([
        'application/pdf',
        'application/msword',
    ])
    ->maxSize(10240) // 10MB
    ->rules(['mimes:pdf,doc,docx', 'max:10240'])
    ->storeFileNamesIn('attachment_file_names')
    ->directory('secure-documents')
    ->visibility('private')
```

### 3. SQL Injection Prevention
```php
// GOOD: Always use parameter binding
public function customQuery(string $search): Collection
{
    return DB::select(
        'SELECT * FROM products WHERE name LIKE :search',
        ['search' => "%{$search}%"]
    );
}
```

## Development Workflow Best Practices

### 1. Resource Generation
```bash
# GOOD: Use artisan commands for consistency
php artisan make:filament-resource Product --generate --soft-deletes
php artisan make:filament-relation-manager ProductResource categories name
php artisan make:filament-widget ProductStats --resource=ProductResource
```

### 2. Version Control
```php
// GOOD: Use migrations for panel configuration
php artisan make:migration add_panel_settings_to_users_table

// In migration
Schema::table('users', function (Blueprint $table) {
    $table->json('panel_settings')->nullable();
    $table->string('preferred_panel')->default('admin');
});
```

### 3. Environment Configuration
```php
// GOOD: Use environment variables
// .env
FILAMENT_FILESYSTEM_DISK=s3
FILAMENT_BROADCASTING_DRIVER=pusher
FILAMENT_CACHE_STORE=redis

// config/filament.php
'default_filesystem_disk' => env('FILAMENT_FILESYSTEM_DISK', 'public'),
```

## Common Patterns

### 1. Dependent Fields Pattern
```php
// GOOD: Reactive dependent fields
Select::make('category_id')
    ->reactive()
    ->afterStateUpdated(function (callable $set) {
        $set('subcategory_id', null);
        $set('price', null);
    })

Select::make('subcategory_id')
    ->options(function (callable $get) {
        $categoryId = $get('category_id');
        if (!$categoryId) {
            return [];
        }
        return Subcategory::where('category_id', $categoryId)
            ->pluck('name', 'id');
    })
    ->reactive()

TextInput::make('price')
    ->prefix('$')
    ->default(function (callable $get) {
        $subcategoryId = $get('subcategory_id');
        if (!$subcategoryId) {
            return null;
        }
        return Subcategory::find($subcategoryId)?->base_price;
    })
```

### 2. Wizard with Validation Pattern
```php
// GOOD: Step-by-step validation
Wizard::make([
    Step::make('Basic Info')
        ->schema([
            TextInput::make('name')->required(),
            TextInput::make('email')->email()->required(),
        ])
        ->afterValidation(function () {
            // Additional validation logic
        }),
    Step::make('Details')
        ->schema([/* ... */])
        ->visible(fn (Get $get) => $get('type') === 'advanced'),
])
->submitAction(
    fn (Action $action) => $action
        ->label('Create')
        ->submit('create')
)
```

### 3. Import/Export Pattern
```php
// GOOD: Bulk import with validation
Tables\Actions\Action::make('import')
    ->form([
        FileUpload::make('file')
            ->acceptedFileTypes(['text/csv'])
            ->required(),
    ])
    ->action(function (array $data) {
        $file = storage_path('app/public/' . $data['file']);
        $import = new ProductsImport();
        
        try {
            Excel::import($import, $file);
            
            Notification::make()
                ->title('Import successful')
                ->body("Imported {$import->getRowCount()} products")
                ->success()
                ->send();
        } catch (\Exception $e) {
            Notification::make()
                ->title('Import failed')
                ->body($e->getMessage())
                ->danger()
                ->send();
        }
    })
```
