# Filament v4 Testing Strategies

## Unit Testing

### 1. Testing Resources

```php
// tests/Feature/Filament/ProductResourceTest.php
namespace Tests\Feature\Filament;

use App\Filament\Resources\ProductResource;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ProductResourceTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected User $user;

    protected function setUp(): void
    {
        parent::setUp();
        
        $this->admin = User::factory()->admin()->create();
        $this->user = User::factory()->create();
    }

    /** @test */
    public function admin_can_list_products()
    {
        $products = Product::factory()->count(5)->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\ListProducts::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords($products)
            ->assertCountTableRecords(5)
            ->assertCanRenderTableColumn('name')
            ->assertCanRenderTableColumn('price')
            ->assertCanNotRenderTableColumn('secret_field');
    }

    /** @test */
    public function admin_can_create_product()
    {
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->fillForm([
                'name' => 'Test Product',
                'description' => 'Test Description',
                'price' => 99.99,
                'stock' => 100,
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

    /** @test */
    public function product_creation_requires_valid_data()
    {
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->fillForm([
                'name' => '',
                'price' => -10,
                'stock' => 'invalid',
            ])
            ->call('create')
            ->assertHasFormErrors([
                'name' => 'required',
                'price' => 'min',
                'stock' => 'numeric',
            ])
            ->assertSeeHtml(__('validation.required', ['attribute' => 'name']));
    }

    /** @test */
    public function regular_user_cannot_access_products()
    {
        Livewire::actingAs($this->user)
            ->test(ProductResource\Pages\ListProducts::class)
            ->assertForbidden();
    }
}
```

### 2. Testing Table Features

```php
class ProductTableTest extends TestCase
{
    /** @test */
    public function can_search_products_by_name()
    {
        Product::factory()->create(['name' => 'Apple iPhone']);
        Product::factory()->create(['name' => 'Samsung Galaxy']);
        Product::factory()->create(['name' => 'Google Pixel']);
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\ListProducts::class)
            ->searchTable('iPhone')
            ->assertCanSeeTableRecords(
                Product::where('name', 'like', '%iPhone%')->get()
            )
            ->assertCanNotSeeTableRecords(
                Product::where('name', 'not like', '%iPhone%')->get()
            );
    }

    /** @test */
    public function can_filter_products_by_status()
    {
        $active = Product::factory()->active()->count(3)->create();
        $inactive = Product::factory()->inactive()->count(2)->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\ListProducts::class)
            ->assertCanSeeTableRecords($active->merge($inactive))
            ->filterTable('status', 'active')
            ->assertCanSeeTableRecords($active)
            ->assertCanNotSeeTableRecords($inactive);
    }

    /** @test */
    public function can_sort_products_by_price()
    {
        $products = Product::factory()->count(3)->create([
            ['price' => 100],
            ['price' => 50],
            ['price' => 150],
        ]);
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\ListProducts::class)
            ->sortTable('price')
            ->assertCanSeeTableRecords($products->sortBy('price'), inOrder: true)
            ->sortTable('price', 'desc')
            ->assertCanSeeTableRecords($products->sortByDesc('price'), inOrder: true);
    }

    /** @test */
    public function can_bulk_delete_products()
    {
        $products = Product::factory()->count(3)->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\ListProducts::class)
            ->selectTableRecords($products->pluck('id')->toArray())
            ->callTableBulkAction('delete')
            ->assertSuccessful();
        
        $this->assertDatabaseCount('products', 0);
    }
}
```

### 3. Testing Forms

```php
class ProductFormTest extends TestCase
{
    /** @test */
    public function form_has_expected_fields()
    {
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->assertFormExists()
            ->assertFormFieldExists('name')
            ->assertFormFieldExists('price')
            ->assertFormFieldExists('category_id')
            ->assertFormFieldIsVisible('name')
            ->assertFormFieldIsEnabled('name')
            ->assertFormFieldIsDisabled('generated_sku');
    }

    /** @test */
    public function conditional_fields_work_correctly()
    {
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->assertFormFieldIsHidden('discount_percentage')
            ->fillForm(['has_discount' => true])
            ->assertFormFieldIsVisible('discount_percentage');
    }

    /** @test */
    public function dependent_selects_update_correctly()
    {
        $category = Category::factory()->hasSubcategories(3)->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->fillForm(['category_id' => $category->id])
            ->assertFormFieldExists('subcategory_id')
            ->assertCountFormFieldOptions('subcategory_id', 3);
    }
}
```

### 4. Testing Actions

```php
class ProductActionTest extends TestCase
{
    /** @test */
    public function can_execute_custom_action()
    {
        $product = Product::factory()->create(['status' => 'pending']);
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\EditProduct::class, [
                'record' => $product->getKey(),
            ])
            ->callAction('approve')
            ->assertHasNoActionErrors()
            ->assertNotified();
        
        $this->assertEquals('approved', $product->fresh()->status);
    }

    /** @test */
    public function action_requires_confirmation()
    {
        $product = Product::factory()->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\EditProduct::class, [
                'record' => $product->getKey(),
            ])
            ->callAction('delete')
            ->assertActionHalted('delete')
            ->assertSee('Are you sure?')
            ->callAction('delete')
            ->assertSuccessful();
    }

    /** @test */
    public function action_validates_input()
    {
        $product = Product::factory()->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\EditProduct::class, [
                'record' => $product->getKey(),
            ])
            ->callAction('updatePrice', data: [
                'percentage' => 'invalid',
            ])
            ->assertHasActionErrors(['percentage' => 'numeric'])
            ->callAction('updatePrice', data: [
                'percentage' => 10,
            ])
            ->assertHasNoActionErrors();
    }
}
```

### 5. Testing Widgets

```php
class ProductStatsWidgetTest extends TestCase
{
    /** @test */
    public function widget_displays_correct_stats()
    {
        Product::factory()->count(5)->create(['price' => 100]);
        Product::factory()->count(3)->create(['status' => 'out_of_stock']);
        
        Livewire::actingAs($this->admin)
            ->test(ProductStatsWidget::class)
            ->assertSee('8') // Total products
            ->assertSee('3') // Out of stock
            ->assertSee('$500'); // Total value
    }

    /** @test */
    public function widget_updates_on_poll()
    {
        Livewire::actingAs($this->admin)
            ->test(ProductStatsWidget::class)
            ->assertSee('0');
        
        Product::factory()->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductStatsWidget::class)
            ->call('$refresh')
            ->assertSee('1');
    }
}
```

## Integration Testing

### 1. Testing Multi-tenancy

```php
class MultiTenancyTest extends TestCase
{
    /** @test */
    public function users_can_only_see_their_teams_products()
    {
        $team1 = Team::factory()->hasProducts(3)->create();
        $team2 = Team::factory()->hasProducts(2)->create();
        $user = User::factory()->belongsToTeam($team1)->create();
        
        Livewire::actingAs($user)
            ->test(ProductResource\Pages\ListProducts::class)
            ->assertCanSeeTableRecords($team1->products)
            ->assertCanNotSeeTableRecords($team2->products)
            ->assertCountTableRecords(3);
    }

    /** @test */
    public function products_are_scoped_to_current_team()
    {
        $user = User::factory()->hasTeams(2)->create();
        $team1 = $user->teams->first();
        $team2 = $user->teams->last();
        
        // Create product for team 1
        Filament::setTenant($team1);
        
        Livewire::actingAs($user)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->fillForm(['name' => 'Team 1 Product'])
            ->call('create');
        
        $this->assertDatabaseHas('products', [
            'name' => 'Team 1 Product',
            'team_id' => $team1->id,
        ]);
    }
}
```

### 2. Testing Notifications

```php
class NotificationTest extends TestCase
{
    /** @test */
    public function user_receives_notification_after_action()
    {
        Notification::fake();
        
        $product = Product::factory()->create();
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\EditProduct::class, [
                'record' => $product->getKey(),
            ])
            ->callAction('approve');
        
        Notification::assertSentTo(
            $this->admin,
            ProductApprovedNotification::class,
            function ($notification, $channels) use ($product) {
                return $notification->product->id === $product->id;
            }
        );
    }

    /** @test */
    public function database_notifications_appear_in_panel()
    {
        $user = User::factory()->create();
        
        $user->notify(new TestNotification('Test Message'));
        
        Livewire::actingAs($user)
            ->test(DatabaseNotifications::class)
            ->assertSee('Test Message')
            ->assertCount('notifications', 1);
    }
}
```

### 3. Testing File Uploads

```php
class FileUploadTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function can_upload_product_image()
    {
        Storage::fake('public');
        
        $file = UploadedFile::fake()->image('product.jpg', 100, 100);
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->fillForm([
                'name' => 'Test Product',
                'image' => [$file],
            ])
            ->call('create');
        
        $product = Product::first();
        
        $this->assertNotNull($product->image);
        Storage::disk('public')->assertExists($product->image);
    }

    /** @test */
    public function validates_file_type_and_size()
    {
        Storage::fake('public');
        
        $invalidFile = UploadedFile::fake()->create('document.pdf', 10000); // 10MB
        
        Livewire::actingAs($this->admin)
            ->test(ProductResource\Pages\CreateProduct::class)
            ->fillForm([
                'image' => [$invalidFile],
            ])
            ->call('create')
            ->assertHasFormErrors(['image' => 'image'])
            ->assertSee('must be an image');
    }
}
```

## E2E Testing with Dusk

### 1. Browser Testing

```php
// tests/Browser/ProductManagementTest.php
namespace Tests\Browser;

use App\Models\User;
use App\Models\Product;
use Laravel\Dusk\Browser;
use Tests\DuskTestCase;

class ProductManagementTest extends DuskTestCase
{
    /** @test */
    public function admin_can_manage_products_flow()
    {
        $admin = User::factory()->admin()->create();
        
        $this->browse(function (Browser $browser) use ($admin) {
            $browser->loginAs($admin)
                ->visit('/admin/products')
                ->assertSee('Products')
                ->press('New product')
                ->waitForText('Create Product')
                ->type('input[wire\\:model="data.name"]', 'Test Product')
                ->type('input[wire\\:model="data.price"]', '99.99')
                ->select('select[wire\\:model="data.category_id"]', '1')
                ->press('Create')
                ->waitForText('Created successfully')
                ->assertPathIs('/admin/products')
                ->assertSee('Test Product')
                ->assertSee('$99.99');
        });
    }

    /** @test */
    public function can_use_table_search_and_filters()
    {
        Product::factory()->count(10)->create();
        Product::factory()->create(['name' => 'Special Product']);
        
        $this->browse(function (Browser $browser) {
            $browser->loginAs(User::factory()->admin()->create())
                ->visit('/admin/products')
                ->type('input[type="search"]', 'Special')
                ->waitForText('Special Product')
                ->assertDontSee('Product 1')
                ->clear('input[type="search"]')
                ->press('Filters')
                ->check('Active only')
                ->press('Apply filters')
                ->waitForReload()
                ->assertQueryStringHas('tableFilters');
        });
    }
}
```

## Test Helpers & Utilities

### 1. Custom Test Helpers

```php
// tests/Filament/TestsFilament.php
trait TestsFilament
{
    protected function createAdmin(): User
    {
        return User::factory()->create([
            'email' => 'admin@test.com',
            'is_admin' => true,
        ]);
    }
    
    protected function assertTableColumnExists(string $column): void
    {
        $this->assertDontSee("Column [{$column}] not found");
    }
    
    protected function assertHasNotification(string $message): void
    {
        $this->assertSee($message)
            ->assertSee('filament-notification');
    }
    
    protected function loginAsAdmin(): self
    {
        return $this->actingAs($this->createAdmin());
    }
}
```

### 2. Factory States

```php
// database/factories/ProductFactory.php
class ProductFactory extends Factory
{
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => true,
            'status' => 'active',
        ]);
    }
    
    public function outOfStock(): static
    {
        return $this->state(fn (array $attributes) => [
            'stock' => 0,
            'status' => 'out_of_stock',
        ]);
    }
    
    public function withReviews(int $count = 3): static
    {
        return $this->hasReviews($count);
    }
}
```

## Testing Best Practices

### 1. Test Organization
```
tests/
├── Unit/
│   ├── Models/
│   ├── Services/
│   └── Helpers/
├── Feature/
│   ├── Filament/
│   │   ├── Resources/
│   │   ├── Pages/
│   │   └── Widgets/
│   ├── Api/
│   └── Auth/
├── Browser/
│   └── Admin/
└── TestCase.php
```

### 2. Test Coverage Checklist

- [ ] Resources: List, Create, Edit, Delete
- [ ] Table: Search, Sort, Filter, Bulk Actions
- [ ] Forms: Validation, Conditional Fields, File Uploads
- [ ] Actions: Authorization, Confirmation, Validation
- [ ] Widgets: Data Display, Polling, Interactions
- [ ] Notifications: Sending, Receiving, Display
- [ ] Multi-tenancy: Scoping, Switching, Isolation
- [ ] Authorization: Policies, Permissions, Roles
- [ ] Performance: Query Count, Load Time
- [ ] Security: XSS, CSRF, SQL Injection

### 3. Continuous Integration

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: password
          MYSQL_DATABASE: testing
        ports:
          - 3306:3306
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite
          coverage: xdebug
      
      - name: Install Dependencies
        run: |
          composer install --no-interaction
          npm ci && npm run build
      
      - name: Run Tests
        env:
          DB_CONNECTION: mysql
          DB_HOST: 127.0.0.1
          DB_PORT: 3306
          DB_DATABASE: testing
          DB_USERNAME: root
          DB_PASSWORD: password
        run: |
          php artisan config:cache
          php artisan test --parallel --coverage
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
```
