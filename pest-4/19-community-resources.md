# Community Resources for Pest

## Official Documentation

### Primary Resources
- **Official Website**: [pestphp.com](https://pestphp.com)
- **Documentation**: [pestphp.com/docs](https://pestphp.com/docs)
- **GitHub Repository**: [github.com/pestphp/pest](https://github.com/pestphp/pest)
- **Release Notes**: [github.com/pestphp/pest/releases](https://github.com/pestphp/pest/releases)

### Official Plugins
- **Laravel Plugin**: [github.com/pestphp/pest-plugin-laravel](https://github.com/pestphp/pest-plugin-laravel)
- **Architecture Plugin**: [github.com/pestphp/pest-plugin-arch](https://github.com/pestphp/pest-plugin-arch)
- **Browser Plugin**: [github.com/pestphp/pest-plugin-browser](https://github.com/pestphp/pest-plugin-browser)
- **Mutation Plugin**: [github.com/pestphp/pest-plugin-mutate](https://github.com/pestphp/pest-plugin-mutate)

## Learning Platforms

### Video Courses
- **Laracasts**: "Pest From Scratch" series
- **SymfonyCasts**: PHP testing with Pest
- **YouTube**: Official PestPHP channel
- **Udemy**: "Master PHP Testing with Pest"

### Written Tutorials
- **Laravel News**: Pest testing articles
- **Dev.to**: Community Pest tutorials
- **Medium**: Pest PHP publications
- **FreeCodeCamp**: Testing PHP applications with Pest

### Interactive Learning
```php
// Practice exercises for learning Pest

// Exercise 1: Basic Expectations
test('practice basic expectations', function () {
    $value = 5;
    // TODO: Assert $value equals 5
    // TODO: Assert $value is an integer
    // TODO: Assert $value is greater than 0
});

// Exercise 2: Working with Arrays
test('practice array expectations', function () {
    $array = ['name' => 'John', 'age' => 30];
    // TODO: Assert array has key 'name'
    // TODO: Assert array count is 2
    // TODO: Assert 'age' value is 30
});

// Exercise 3: Exception Testing
test('practice exception testing', function () {
    // TODO: Test that dividing by zero throws an exception
    // TODO: Test the exception message
    // TODO: Test the exception type
});
```

## Community Forums

### Discord
- **Official Pest Discord**: Join for real-time help
- **Laravel Discord**: #testing channel
- **PHP Discord**: Testing discussions

### Stack Overflow
```markdown
# Useful Stack Overflow Tags
- [pest-php] - Main Pest tag
- [pest-php-testing] - Testing specific
- [laravel-pest] - Laravel integration
- [phpunit] + [pest] - Migration questions
```

### Reddit Communities
- r/PHP - PHP testing discussions
- r/laravel - Laravel + Pest topics
- r/PHPhelp - Testing help

### GitHub Discussions
- [Pest Discussions](https://github.com/pestphp/pest/discussions)
- Feature requests
- Bug reports
- Community showcases

## Conferences and Events

### Major Conferences
- **Laracon** - Annual Pest presentations
- **PHP UK Conference** - Testing workshops
- **SymfonyLive** - PHP testing talks
- **PHPConference** - Pest sessions

### Meetups
```php
// Find local Pest/PHP testing meetups
$meetups = [
    'PHP User Groups' => 'Testing nights',
    'Laravel Meetups' => 'Pest demonstrations',
    'Testing Communities' => 'Cross-framework events'
];
```

### Webinars
- Monthly Pest webinars by maintainers
- Community-led tutorials
- Plugin showcases
- Migration guides

## Contributing to Open Source

### Getting Started with Contributing
```bash
# Fork and clone Pest
git clone https://github.com/your-username/pest.git
cd pest

# Install dependencies
composer install

# Run tests
./vendor/bin/pest

# Create feature branch
git checkout -b feature/your-feature
```

### Contribution Guidelines
```php
// Example: Contributing a new expectation
// src/Expectations/toBeWithinRange.php

expect()->extend('toBeWithinRange', function (float $min, float $max) {
    return $this->toBeGreaterThanOrEqual($min)
                ->toBeLessThanOrEqual($max);
});

// tests/Expectations/ToBeWithinRangeTest.php
test('toBeWithinRange expectation works', function () {
    expect(5)->toBeWithinRange(1, 10);
    expect(10)->toBeWithinRange(10, 20);
    
    expect(fn() => expect(0)->toBeWithinRange(1, 10))
        ->toThrow(ExpectationFailedException::class);
});
```

### Creating Pest Plugins
```php
// composer.json for a Pest plugin
{
    "name": "yourname/pest-plugin-example",
    "description": "A Pest plugin for...",
    "require": {
        "pestphp/pest": "^4.0",
        "pestphp/pest-plugin": "^4.0"
    },
    "autoload": {
        "psr-4": {
            "YourName\\PestPluginExample\\": "src/"
        },
        "files": ["src/Functions.php"]
    },
    "extra": {
        "pest": {
            "plugins": [
                "YourName\\PestPluginExample\\Plugin"
            ]
        }
    }
}

// src/Plugin.php
namespace YourName\PestPluginExample;

class Plugin implements \Pest\Contracts\Plugin
{
    public function boot(): void
    {
        // Plugin initialization
    }
}
```

### Pull Request Best Practices
```markdown
## PR Template for Pest Contributions

### Description
Brief description of changes

### Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

### Testing
- [ ] Tests pass locally
- [ ] New tests added
- [ ] Coverage maintained

### Documentation
- [ ] Updated relevant docs
- [ ] Added examples

### Breaking Changes
- [ ] None
- [ ] Listed below:
```

## Pest Ecosystem

### Popular Community Packages
```bash
# Snapshot testing
composer require spatie/pest-plugin-snapshots --dev

# Test time helpers
composer require spatie/pest-plugin-test-time --dev

# OpenAPI testing
composer require osteel/openapi-httpfoundation-testing --dev

# Database assertions
composer require worksome/pest-plugin-database-assertions --dev

# Performance testing
composer require pestphp/pest-plugin-stressless --dev
```

### Package Discovery
```php
// Search for Pest packages on Packagist
// https://packagist.org/?query=pest-plugin

// Evaluate packages before using
test('package is actively maintained', function ($package) {
    $lastCommit = GitHub::repo($package)->commits()->latest();
    $daysSinceLastCommit = now()->diffInDays($lastCommit->date);
    
    expect($daysSinceLastCommit)->toBeLessThan(180);
})->with(['pest-plugin-examples']);
```

## Blog Posts and Articles

### Must-Read Articles
1. "Getting Started with Pest" - Laravel News
2. "From PHPUnit to Pest: A Migration Story" - Dev.to
3. "Architecture Testing with Pest" - Medium
4. "Browser Testing in Pest v4" - Official Blog
5. "Mutation Testing Explained" - PHP Architect

### Community Blogs
```markdown
## Recommended Pest Blogs

### Individual Developers
- Nuno Maduro (Pest creator) - nunomaduro.com
- Freek Van der Herten - freek.dev
- Marcel Pociot - beyondco.de
- Christoph Rumpel - christoph-rumpel.com

### Company Blogs
- Spatie - spatie.be/blog
- Beyond Code - beyondco.de/blog
- Laravel News - laravel-news.com
- Tighten - tighten.co/blog
```

## Social Media

### Twitter/X
- [@pestphp](https://twitter.com/pestphp) - Official account
- [@nunomaduro](https://twitter.com/nunomaduro) - Creator
- [@enunomaduro](https://twitter.com/enunomaduro) - Updates
- #pestphp - Community hashtag

### LinkedIn
- PestPHP group discussions
- Testing best practices
- Career opportunities

### YouTube Channels
- PestPHP Official
- Laracasts
- Laravel Daily
- Codecourse

## Books and Publications

### Books
- "Testing PHP with Pest" (upcoming)
- "Laravel Testing Decoded" - Includes Pest chapter
- "Modern PHP Testing" - Pest coverage

### Magazine Articles
- PHP Architect - Regular Pest articles
- php[architect] - Testing columns
- Laravel Magazine - Pest tutorials

## Code Examples and Templates

### Starter Templates
```bash
# Laravel + Pest starter
composer create-project laravel/laravel pest-app
cd pest-app
composer require pestphp/pest-plugin-laravel --dev
./vendor/bin/pest --init

# Symfony + Pest starter
composer create-project symfony/skeleton pest-symfony
cd pest-symfony
composer require pestphp/pest --dev
./vendor/bin/pest --init
```

### Example Repositories
- [pestphp/examples](https://github.com/pestphp/examples)
- [laravel/laravel](https://github.com/laravel/laravel) - Includes Pest
- Community showcases on GitHub

## Support Channels

### Commercial Support
- Laravel consulting firms
- PHP development agencies
- Freelance Pest experts

### Community Support
```php
// Getting help template
test('issue reproduction', function () {
    // Minimal reproduction of your issue
    // Include:
    // - Pest version
    // - PHP version
    // - Relevant code
    // - Error message
    // - Expected behavior
})->skip('For demonstration only');
```

### Sponsorship
- GitHub Sponsors for Pest
- OpenCollective
- Support maintainers directly

## Certification and Training

### Online Certifications
- Laravel Certification (includes Pest)
- PHP Testing Certification
- TDD Certification programs

### Workshops
```markdown
## Pest Workshop Topics

### Beginner
- Introduction to Pest
- Writing your first test
- Basic expectations
- Test organization

### Intermediate
- Datasets and data providers
- Mocking and test doubles
- Laravel integration
- Architecture testing

### Advanced
- Browser testing
- Mutation testing
- Custom plugins
- Performance optimization
```

## Future of Pest

### Roadmap
- Enhanced browser testing
- AI-assisted test generation
- Better IDE integration
- Performance improvements
- More architectural presets

### Community Wishlist
```php
// Vote for features
$features = [
    'Visual test recorder',
    'Test impact analysis',
    'Automatic test generation',
    'Cross-browser testing',
    'Better async support',
];
```

## Quick Reference Links

### Essential Links
- Documentation: pestphp.com/docs
- GitHub: github.com/pestphp/pest
- Discord: discord.gg/pestphp
- Twitter: @pestphp
- Sponsors: github.com/sponsors/nunomaduro

### Plugin Links
- Laravel: pestphp.com/docs/plugins/laravel
- Architecture: pestphp.com/docs/arch-testing
- Browser: pestphp.com/docs/browser-testing
- Mutations: pestphp.com/docs/mutation-testing

### Learning Resources
- Video Courses: laracasts.com/topics/pest
- Articles: laravel-news.com/tag/pest
- Examples: github.com/pestphp/examples
- Community: discord.gg/pestphp