# Filament v4 Anti-Patterns & Common Mistakes

## Critical Anti-Patterns to Avoid

### 1. ❌ N+1 Query Problems
**What it looks like:**
```php
// BAD: Loading relationships in table columns without eager loading
TextColumn::make('category.name')
    ->label('Category')

TextColumn::make('user.email')
    ->label('User Email')

// This will execute separate queries for each row!
```

**Why it's bad:**
- Executes hundreds of queries for large tables
- Extremely slow page loads
- Database connection overload

**Do this instead:**
```php
// GOOD: Eager load relationships
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->with(['category', 'user']);
}

// Or use modifyQueryUsing
public static function table(Table $table): Table
{
    return $table
        ->modifyQueryUsing(fn (Builder $query) => 
            $query->with(['category:id,name', 'user:id,email'])
        );
}
```

### 2. ❌ Not Using Filament's Built-in Features
**What it looks like:**
```php
// BAD: Custom validation logic
TextInput::make('email')
    ->afterStateUpdated(function ($state, $component) {
        if (!filter_var($state, FILTER_VALIDATE_EMAIL)) {
            $component->state('');
            // Custom error handling
        }
    })

// BAD: Manual file handling
FileUpload::make('avatar')
    ->afterStateHydrated(function ($component, $state) {
        // Custom file processing logic
    })
```

**Do this instead:**
```php
// GOOD: Use built-in validation
TextInput::make('email')
    ->email()
    ->required()
    ->unique(ignoreRecord: true)

// GOOD: Use built-in file features
FileUpload::make('avatar')
    ->image()
    ->imageEditor()
    ->optimize('webp')
```

### 3. ❌ Blocking Operations in Lifecycle Hooks
**What it looks like:**
```php
// BAD: Heavy operations in reactive fields
TextInput::make('name')
    ->reactive()
    ->afterStateUpdated(function ($state) {
        // Synchronous API call
        $result = Http::timeout(30)->get('https://api.example.com/validate/' . $state);
        
        // Heavy database operations
        Product::where('name', 'like', "%{$state}%")
            ->with(['orders', 'reviews', 'categories'])
            ->get()
            ->each(function ($product) {
                // Process each product
            });
    })
```

**Do this instead:**
```php
// GOOD: Use jobs for heavy operations
->afterStateUpdated(function ($state) {
    dispatch(new ValidateProductName($state));
})

// GOOD: Debounce reactive updates
->reactive()
->debounce(500)
```

### 4. ❌ Ignoring Authorization
**What it looks like:**
```php
// BAD: No authorization checks
class ProductResource extends Resource
{
    // No canViewAny, canCreate, etc. methods
    // No policy checks on actions
}

// BAD: Authorization only in some places
Tables\Actions\DeleteAction::make()
    // No ->authorize() call
```

**Do this instead:**
```php
// GOOD: Comprehensive authorization
class ProductResource extends Resource
{
    public static function canViewAny(): bool
    {
        return auth()->user()->can('viewAny', Product::class);
    }

    // In table actions
    Tables\Actions\DeleteAction::make()
        ->authorize('delete')
}
```

### 5. ❌ Not Handling Errors Properly
**What it looks like:**
```php
// BAD: Silent failures
Tables\Actions\Action::make('process')
    ->action(function ($record) {
        $record->process(); // What if this fails?
    })

// BAD: Generic error messages
->action(function ($record) {
    try {
        $record->process();
    } catch (\Exception $e) {
        throw new \Exception('Error occurred');
    }
})
```

**Do this instead:**
```php
// GOOD: Proper error handling with notifications
->action(function ($record) {
    try {
        $result = $record->process();
        
        Notification::make()
            ->title('Processing complete')
            ->success()
            ->send();
            
        return $result;
    } catch (ProcessingException $e) {
        Notification::make()
            ->title('Processing failed')
            ->body($e->getMessage())
            ->danger()
            ->persistent()
            ->send();
            
        Log::error('Processing failed', [
            'record' => $record->id,
            'error' => $e->getMessage()
        ]);
        
        throw $e;
    }
})
```

### 6. ❌ Inefficient File Handling
**What it looks like:**
```php
// BAD: No optimization or validation
FileUpload::make('images')
    ->multiple()
    // No size limits
    // No type validation
    // No image optimization

// BAD: Storing files in database
FileUpload::make('document')
    ->storeFiles(false) // Storing as base64 in database
```

**Do this instead:**
```php
// GOOD: Optimized file handling
FileUpload::make('images')
    ->multiple()
    ->image()
    ->imageEditor()
    ->maxSize(2048)
    ->maxFiles(5)
    ->acceptedFileTypes(['image/jpeg', 'image/png'])
    ->imageResizeMode('cover')
    ->imageResizeTargetWidth('1920')
    ->imageResizeTargetHeight('1080')
    ->optimize('webp')
    ->directory('products')
    ->disk('s3')
```

### 7. ❌ Memory Leaks in Widgets
**What it looks like:**
```php
// BAD: Not cleaning up intervals/listeners
class StatsWidget extends Widget
{
    protected static ?string $pollingInterval = '1s'; // Too frequent
    
    public function mount(): void
    {
        // Setting up listeners without cleanup
        Event::listen('product.updated', [$this, 'refresh']);
    }
    // Never removing listeners
}
```

**Do this instead:**
```php
// GOOD: Proper cleanup and reasonable intervals
class StatsWidget extends Widget
{
    protected static ?string $pollingInterval = '30s';
    
    public function mount(): void
    {
        Event::listen('product.updated', [$this, 'refresh']);
    }
    
    public function unmount(): void
    {
        Event::forget('product.updated');
    }
}
```

### 8. ❌ Overusing Reactive Fields
**What it looks like:**
```php
// BAD: Everything is reactive
TextInput::make('field1')->reactive()
TextInput::make('field2')->reactive()
TextInput::make('field3')->reactive()
TextInput::make('field4')->reactive()
TextInput::make('field5')->reactive()
// Makes form very slow
```

**Do this instead:**
```php
// GOOD: Only make fields reactive when necessary
Select::make('country')
    ->reactive() // Only this needs to be reactive
    
Select::make('state')
    ->options(fn (Get $get) => 
        Country::find($get('country'))?->states ?? []
    )
    // Not reactive unless it affects other fields
```

### 9. ❌ Not Using Transactions
**What it looks like:**
```php
// BAD: Multiple operations without transaction
protected function mutateFormDataBeforeCreate(array $data): array
{
    $product = Product::create($data);
    $product->categories()->attach($data['categories']);
    $product->tags()->create($data['tags']);
    // If tags creation fails, product and categories are already saved!
}
```

**Do this instead:**
```php
// GOOD: Wrap in transaction
protected function handleRecordCreation(array $data): Model
{
    return DB::transaction(function () use ($data) {
        $product = Product::create($data);
        $product->categories()->attach($data['categories']);
        $product->tags()->create($data['tags']);
        return $product;
    });
}
```

### 10. ❌ Hardcoding Values
**What it looks like:**
```php
// BAD: Magic values everywhere
TextInput::make('price')
    ->minValue(0)
    ->maxValue(99999) // What's this limit?

Select::make('status')
    ->options([
        'pending' => 'Pending',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
    ])
    // Duplicated in multiple places
```

**Do this instead:**
```php
// GOOD: Use constants and enums
class ProductStatus extends Enum
{
    const PENDING = 'pending';
    const APPROVED = 'approved';
    const REJECTED = 'rejected';
}

Select::make('status')
    ->options(ProductStatus::options())

TextInput::make('price')
    ->minValue(config('shop.min_price'))
    ->maxValue(config('shop.max_price'))
```

### 11. ❌ Ignoring Livewire Lifecycle
**What it looks like:**
```php
// BAD: Not understanding Livewire state
public function save()
{
    $this->record->save();
    
    // Trying to access DOM directly
    $this->dispatchBrowserEvent('close-modal');
    
    // Not refreshing the form
}
```

**Do this instead:**
```php
// GOOD: Work with Livewire properly
public function save()
{
    $this->record->save();
    
    $this->fillForm();
    
    Notification::make()
        ->title('Saved successfully')
        ->success()
        ->send();
        
    $this->dispatch('refreshTable');
}
```

### 12. ❌ Poor Table Performance
**What it looks like:**
```php
// BAD: Loading everything at once
public static function table(Table $table): Table
{
    return $table
        ->columns([
            TextColumn::make('full_description') // Loading large text
                ->formatStateUsing(fn ($state) => 
                    Str::limit($state, 50) // Processing in PHP
                ),
        ])
        ->paginated(false) // No pagination!
}
```

**Do this instead:**
```php
// GOOD: Optimize table queries
public static function table(Table $table): Table
{
    return $table
        ->columns([
            TextColumn::make('description')
                ->limit(50) // Let Filament handle truncation
                ->tooltip(function (Model $record): string {
                    return $record->full_description;
                }),
        ])
        ->paginated([10, 25, 50])
        ->deferLoading() // Load only when needed
        ->poll('30s')
}
```

### 13. ❌ Not Testing Resources
**What it looks like:**
```php
// BAD: No tests for critical resources
// Changing forms/tables without testing
// No validation testing
// No authorization testing
```

**Do this instead:**
```php
// GOOD: Comprehensive testing
public function test_product_resource()
{
    $this->actingAs($admin);
    
    // Test index
    Livewire::test(ListProducts::class)
        ->assertCanSeeTableRecords(Product::limit(10)->get());
    
    // Test create
    Livewire::test(CreateProduct::class)
        ->fillForm([
            'name' => 'Test Product',
            'price' => 99.99,
        ])
        ->call('create')
        ->assertHasNoFormErrors();
    
    // Test validation
    Livewire::test(CreateProduct::class)
        ->fillForm(['name' => ''])
        ->call('create')
        ->assertHasFormErrors(['name' => 'required']);
}
```

### 14. ❌ Complex Form Schemas
**What it looks like:**
```php
// BAD: Deeply nested, hard to maintain
Grid::make(3)
    ->schema([
        Section::make()
            ->schema([
                Grid::make(2)
                    ->schema([
                        Fieldset::make()
                            ->schema([
                                Grid::make(3)
                                    ->schema([
                                        // 5 levels deep!
                                    ])
                            ])
                    ])
            ])
    ])
```

**Do this instead:**
```php
// GOOD: Flat, organized structure
Section::make('Basic Information')
    ->schema([
        TextInput::make('name'),
        TextInput::make('email'),
    ])
    ->columns(2),

Section::make('Address')
    ->schema([
        TextInput::make('street'),
        TextInput::make('city'),
    ])
    ->columns(2),
```

### 15. ❌ Not Using Filament Conventions
**What it looks like:**
```php
// BAD: Fighting the framework
class ProductController extends Controller
{
    // Building custom CRUD instead of using resources
}

// BAD: Custom routing
Route::get('/admin/products', [ProductController::class, 'index']);
```

**Do this instead:**
```php
// GOOD: Use Filament's resource system
class ProductResource extends Resource
{
    // Let Filament handle routing, controllers, views
}
```

## Red Flags in Code Reviews

### Watch out for:
- Missing `with()` in Eloquent queries
- No `->authorize()` on actions
- Empty catch blocks in actions
- `->reactive()` on every field
- No validation rules on inputs
- Hardcoded strings/numbers
- No pagination on tables
- Missing database transactions
- No error notifications
- Files without size/type limits
- Synchronous heavy operations
- No caching for expensive operations
- Missing tests for resources
- Direct DOM manipulation
- Using `dd()` or `dump()` in production code

## Performance Anti-Patterns

### 1. ❌ Loading Too Much Data
```php
// BAD
Product::all() // Loading everything
Product::with(['orders', 'reviews', 'categories', 'tags']) // Over-eager loading
```

### 2. ❌ Not Using Indexes
```php
// BAD: Searching/filtering on non-indexed columns
TextColumn::make('description')
    ->searchable() // Description is not indexed!
```

### 3. ❌ Inefficient Computed Columns
```php
// BAD: Computing in PHP instead of database
TextColumn::make('total_revenue')
    ->getStateUsing(fn ($record) => 
        $record->orders->sum('total') // Loads all orders!
    )
```

## Security Anti-Patterns

### 1. ❌ Exposing Sensitive Data
```php
// BAD: Showing sensitive fields to everyone
TextInput::make('api_key')
TextInput::make('password_plain_text')
```

### 2. ❌ No Rate Limiting
```php
// BAD: Actions without rate limiting
Action::make('send_email')
    ->action(fn () => Mail::send(...))
    // Can be spammed!
```

### 3. ❌ Trusting User Input
```php
// BAD: Using user input directly
->action(function ($record, array $data) {
    DB::statement("UPDATE products SET name = '{$data['name']}'");
})
```
