# Filament 4 Quick Start Guide

## Installation

### Requirements
- PHP 8.2+
- Laravel 11.0+
- Node.js 18+

### Step 1: Create Laravel Project

```bash
# Using Laravel installer
laravel new my-project

# Or using Composer
composer create-project laravel/laravel my-project

cd my-project
```

### Step 2: Install Filament

```bash
# Install Filament packages
composer require filament/filament:"^4.0"

# Run the installation command
php artisan filament:install --panels
```

### Step 3: Create Admin User

```bash
php artisan make:filament-user
```

Follow the prompts to create your admin account:
- Name
- Email
- Password

### Step 4: Access Admin Panel

```bash
php artisan serve
```

Visit: `http://localhost:8000/admin`

## Creating Your First Resource

### Step 1: Create Model & Migration

```bash
# Create Product model with migration
php artisan make:model Product -m
```

Edit migration file:

```php
// database/migrations/xxxx_create_products_table.php
Schema::create('products', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->text('description')->nullable();
    $table->decimal('price', 10, 2);
    $table->integer('stock')->default(0);
    $table->boolean('is_active')->default(true);
    $table->string('image')->nullable();
    $table->timestamps();
});
```

Run migration:

```bash
php artisan migrate
```

### Step 2: Generate Filament Resource

```bash
php artisan make:filament-resource Product
```

This creates:
- `app/Filament/Resources/ProductResource.php`
- `app/Filament/Resources/ProductResource/Pages/`
- Form and Table definitions

### Step 3: Define Table Columns

```php
// app/Filament/Resources/ProductResource.php

public static function table(Table $table): Table
{
    return $table
        ->columns([
            TextColumn::make('name')
                ->searchable()
                ->sortable(),
            TextColumn::make('price')
                ->money('USD')
                ->sortable(),
            TextColumn::make('stock')
                ->badge()
                ->color(fn (int $state): string => match (true) {
                    $state === 0 => 'danger',
                    $state < 10 => 'warning',
                    default => 'success',
                }),
            ToggleColumn::make('is_active')
                ->label('Active'),
            TextColumn::make('created_at')
                ->dateTime()
                ->sortable()
                ->toggleable(isToggledHiddenByDefault: true),
        ])
        ->filters([
            SelectFilter::make('is_active')
                ->options([
                    '1' => 'Active',
                    '0' => 'Inactive',
                ]),
        ])
        ->actions([
            Tables\Actions\EditAction::make(),
            Tables\Actions\DeleteAction::make(),
        ])
        ->bulkActions([
            Tables\Actions\DeleteBulkAction::make(),
        ]);
}
```

### Step 4: Define Form Fields

```php
public static function form(Form $form): Form
{
    return $form
        ->schema([
            TextInput::make('name')
                ->required()
                ->maxLength(255)
                ->placeholder('Product name'),
            
            Textarea::make('description')
                ->maxLength(1000)
                ->rows(3),
            
            TextInput::make('price')
                ->numeric()
                ->required()
                ->prefix('$')
                ->minValue(0),
            
            TextInput::make('stock')
                ->numeric()
                ->required()
                ->default(0)
                ->minValue(0),
            
            Toggle::make('is_active')
                ->label('Active')
                ->default(true),
            
            FileUpload::make('image')
                ->image()
                ->directory('products')
                ->maxSize(2048),
        ]);
}
```

## Common Patterns

### Adding Relation Managers

```bash
php artisan make:filament-relation-manager ProductResource categories name
```

### Creating Custom Pages

```bash
php artisan make:filament-page ProductReport --resource=ProductResource
```

### Adding Widgets to Dashboard

```bash
php artisan make:filament-widget ProductStats --resource=ProductResource
```

Widget example:

```php
// app/Filament/Widgets/ProductStats.php

protected function getStats(): array
{
    return [
        Stat::make('Total Products', Product::count())
            ->description('All time')
            ->descriptionIcon('heroicon-m-arrow-trending-up')
            ->color('success'),
        
        Stat::make('Active Products', Product::where('is_active', true)->count())
            ->description('Currently active')
            ->color('primary'),
        
        Stat::make('Low Stock', Product::where('stock', '<', 10)->count())
            ->description('Need restocking')
            ->color('warning'),
    ];
}
```

### Global Search

```php
// In ProductResource.php

public static function getGlobalSearchResultTitle(Model $record): string
{
    return $record->name;
}

public static function getGloballySearchableAttributes(): array
{
    return ['name', 'description'];
}
```

### Custom Actions

```php
// Table action
Tables\Actions\Action::make('duplicate')
    ->icon('heroicon-o-document-duplicate')
    ->action(function (Product $record) {
        $newProduct = $record->replicate();
        $newProduct->name = $record->name . ' (Copy)';
        $newProduct->save();
    }),

// Bulk action
Tables\Actions\BulkAction::make('updatePrice')
    ->icon('heroicon-o-currency-dollar')
    ->form([
        TextInput::make('percentage')
            ->label('Price increase (%)')
            ->numeric()
            ->required(),
    ])
    ->action(function (Collection $records, array $data) {
        $records->each(function ($record) use ($data) {
            $record->price *= (1 + $data['percentage'] / 100);
            $record->save();
        });
    }),
```

### Notifications

```php
use Filament\Notifications\Notification;

// Success notification
Notification::make()
    ->title('Product created successfully')
    ->success()
    ->send();

// Warning with action
Notification::make()
    ->title('Low stock alert')
    ->body('Some products are running low on stock.')
    ->warning()
    ->persistent()
    ->actions([
        Action::make('view')
            ->button()
            ->url(route('filament.admin.resources.products.index')),
    ])
    ->send();
```

## Advanced Features

### Multi-tenancy

```php
// In AdminPanelProvider.php
->tenant(Team::class)
->tenantMenu()
->tenantProfile()
```

### Custom Theme

```bash
php artisan make:filament-theme
```

```css
/* resources/css/filament/admin/theme.css */
@import '/vendor/filament/filament/resources/css/theme.css';

@layer base {
    :root {
        --primary-50: 239 246 255;
        --primary-600: 79 70 229;
        /* Custom colors */
    }
}
```

### Policy Authorization

```php
// app/Policies/ProductPolicy.php
public function viewAny(User $user): bool
{
    return $user->hasPermission('view_products');
}

public function create(User $user): bool
{
    return $user->hasPermission('create_products');
}
```

### API Resources

```php
// Expose resource as API
public static function getApiResource(): string
{
    return \App\Http\Resources\ProductResource::class;
}
```

## Best Practices

1. **Use Policies**: Always implement model policies for authorization
2. **Optimize Queries**: Use `with()` for eager loading relationships
3. **Cache Heavy Operations**: Cache expensive computations
4. **Validate Input**: Use Laravel's validation rules
5. **Test Resources**: Write feature tests for your resources
6. **Use Translations**: Make your app multilingual ready
7. **Monitor Performance**: Use Laravel Telescope or Debugbar
8. **Version Control**: Commit your Filament customizations

## Troubleshooting

### Common Issues

**Assets not loading**
```bash
php artisan filament:assets
php artisan cache:clear
```

**Styles not applying**
```bash
npm run build
php artisan optimize:clear
```

**Permission errors**
```bash
php artisan cache:clear
php artisan config:clear
php artisan route:clear
```

**Migration issues**
```bash
php artisan migrate:fresh --seed
```

## Next Steps

1. Explore the [Component Gallery](https://filamentphp.com/docs/forms/fields)
2. Learn about [Custom Fields](https://filamentphp.com/docs/forms/fields/custom)
3. Implement [Testing](https://filamentphp.com/docs/panels/testing)
4. Add [Plugins](https://filamentphp.com/plugins)
5. Join the [Community](https://filamentphp.com/discord)
