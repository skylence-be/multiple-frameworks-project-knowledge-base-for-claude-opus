# Filament 4 Components Reference

## Form Components

### Input Fields

#### TextInput
```php
TextInput::make('name')
    ->required()
    ->maxLength(255)
    ->placeholder('Enter name')
    ->autocomplete('name')
    ->autofocus()
    ->disabled()
    ->readOnly()
    ->prefix('$')
    ->suffix('.com')
    ->helperText('Your full name')
    ->hint('Max 255 characters')
    ->hintIcon('heroicon-o-information-circle')
```

#### Textarea
```php
Textarea::make('description')
    ->required()
    ->maxLength(1000)
    ->rows(5)
    ->cols(20)
    ->autosize() // Auto-resize
    ->placeholder('Enter description...')
```

#### Select
```php
Select::make('status')
    ->options([
        'draft' => 'Draft',
        'published' => 'Published',
        'archived' => 'Archived',
    ])
    ->required()
    ->searchable()
    ->multiple()
    ->native(false) // Use custom select
    ->preload() // Load all options
    ->createOptionForm([
        TextInput::make('name')->required(),
    ])
```

#### Radio
```php
Radio::make('priority')
    ->options([
        'low' => 'Low',
        'medium' => 'Medium',
        'high' => 'High',
    ])
    ->inline()
    ->descriptions([
        'low' => 'Response within 48 hours',
        'medium' => 'Response within 24 hours',
        'high' => 'Immediate response',
    ])
```

#### Checkbox & Toggle
```php
Checkbox::make('is_featured')
    ->label('Feature this item')
    ->helperText('This will appear on the homepage')

Toggle::make('is_active')
    ->onColor('success')
    ->offColor('danger')
    ->onIcon('heroicon-s-check')
    ->offIcon('heroicon-s-x-mark')
```

### Date & Time

#### DatePicker
```php
DatePicker::make('published_at')
    ->required()
    ->minDate(now())
    ->maxDate(now()->addMonth())
    ->displayFormat('d/m/Y')
    ->native(false) // Use JS picker
    ->closeOnDateSelection()
    ->weekStartsOnMonday()
```

#### DateTimePicker
```php
DateTimePicker::make('scheduled_at')
    ->seconds(false)
    ->timezone('America/New_York')
    ->minDate(now())
    ->displayFormat('d M Y H:i')
```

#### TimePicker
```php
TimePicker::make('appointment_time')
    ->seconds(false)
    ->minutesStep(15)
    ->minTime('09:00')
    ->maxTime('17:00')
```

### File Management

#### FileUpload
```php
FileUpload::make('avatar')
    ->image()
    ->avatar()
    ->directory('avatars')
    ->disk('public')
    ->maxSize(2048) // 2MB
    ->minSize(10) // 10KB
    ->acceptedFileTypes(['image/jpeg', 'image/png'])
    ->imageResizeMode('cover')
    ->imageCropAspectRatio('1:1')
    ->imageResizeTargetWidth('500')
    ->imageResizeTargetHeight('500')
    ->removeUploadedFileButtonPosition('right')
    ->uploadProgressIndicatorPosition('right')
    ->panelLayout('grid')
    ->panelAspectRatio('16:9')
    ->previewable()
    ->downloadable()
    ->openable()
    ->reorderable()
    ->appendFiles() // Don't replace existing
```

### Rich Content

#### RichEditor
```php
RichEditor::make('content')
    ->toolbarButtons([
        'bold',
        'italic',
        'underline',
        'strike',
        'link',
        'bulletList',
        'orderedList',
        'h2',
        'h3',
        'blockquote',
        'codeBlock',
        'table',
    ])
    ->fileAttachmentsDisk('public')
    ->fileAttachmentsDirectory('attachments')
    ->fileAttachmentsVisibility('public')
```

#### MarkdownEditor
```php
MarkdownEditor::make('content')
    ->toolbarButtons([
        'bold',
        'italic',
        'strike',
        'link',
        'heading',
        'codeBlock',
        'bulletList',
        'orderedList',
        'table',
        'attachFiles',
    ])
    ->fileAttachmentsDisk('public')
    ->fileAttachmentsDirectory('attachments')
```

### Advanced Fields

#### Repeater
```php
Repeater::make('items')
    ->schema([
        TextInput::make('name')->required(),
        TextInput::make('quantity')->numeric()->required(),
        TextInput::make('price')->numeric()->prefix('$'),
    ])
    ->columns(3)
    ->defaultItems(1)
    ->minItems(1)
    ->maxItems(10)
    ->reorderable()
    ->collapsible()
    ->cloneable()
    ->itemLabel(fn (array $state): ?string => $state['name'] ?? null)
```

#### Builder
```php
Builder::make('content')
    ->blocks([
        Builder\Block::make('heading')
            ->schema([
                TextInput::make('content')->required(),
                Select::make('level')
                    ->options([
                        'h1' => 'H1',
                        'h2' => 'H2',
                        'h3' => 'H3',
                    ])
                    ->required(),
            ]),
        Builder\Block::make('paragraph')
            ->schema([
                Textarea::make('content')->required(),
            ]),
        Builder\Block::make('image')
            ->schema([
                FileUpload::make('url')->image()->required(),
                TextInput::make('alt'),
            ]),
    ])
    ->collapsible()
    ->cloneable()
    ->reorderable()
```

#### KeyValue
```php
KeyValue::make('metadata')
    ->keyLabel('Key')
    ->valueLabel('Value')
    ->addButtonLabel('Add metadata')
    ->reorderable()
    ->deletable()
    ->addable()
    ->editableKeys()
```

#### TagsInput
```php
TagsInput::make('tags')
    ->separator(',')
    ->suggestions([
        'laravel',
        'filament',
        'php',
        'javascript',
    ])
    ->splitKeys(['Tab', 'Enter'])
```

## Table Components

### Columns

#### TextColumn
```php
TextColumn::make('name')
    ->searchable()
    ->sortable()
    ->toggleable()
    ->copyable()
    ->copyMessage('Copied!')
    ->limit(50)
    ->tooltip(fn (Model $record): string => $record->full_description)
    ->formatStateUsing(fn (string $state): string => ucfirst($state))
    ->html() // Render as HTML
    ->money('USD')
    ->dateTime('M j, Y')
    ->since() // Human-readable time
    ->badge()
    ->color('success')
    ->icon('heroicon-o-check-circle')
    ->iconPosition('after')
```

#### ImageColumn
```php
ImageColumn::make('avatar')
    ->circular()
    ->size(40)
    ->defaultImageUrl(url('/default-avatar.png'))
    ->extraImgAttributes(['loading' => 'lazy'])
```

#### IconColumn
```php
IconColumn::make('is_featured')
    ->boolean()
    ->trueIcon('heroicon-o-check-circle')
    ->falseIcon('heroicon-o-x-circle')
    ->trueColor('success')
    ->falseColor('danger')
```

#### ToggleColumn
```php
ToggleColumn::make('is_active')
    ->onColor('success')
    ->offColor('danger')
    ->afterStateUpdated(function ($record, $state) {
        // Handle after update
    })
```

#### SelectColumn
```php
SelectColumn::make('status')
    ->options([
        'pending' => 'Pending',
        'processing' => 'Processing',
        'completed' => 'Completed',
    ])
    ->selectablePlaceholder(false)
```

### Filters

#### SelectFilter
```php
SelectFilter::make('status')
    ->options([
        'active' => 'Active',
        'inactive' => 'Inactive',
    ])
    ->multiple()
    ->placeholder('All statuses')
    ->default('active')
```

#### TernaryFilter
```php
TernaryFilter::make('is_featured')
    ->label('Featured')
    ->placeholder('All products')
    ->trueLabel('Featured only')
    ->falseLabel('Not featured')
    ->queries(
        true: fn ($query) => $query->where('is_featured', true),
        false: fn ($query) => $query->where('is_featured', false),
    )
```

#### DateFilter
```php
Filter::make('created_at')
    ->form([
        DatePicker::make('created_from'),
        DatePicker::make('created_until'),
    ])
    ->query(function (Builder $query, array $data): Builder {
        return $query
            ->when($data['created_from'], 
                fn ($query, $date) => $query->whereDate('created_at', '>=', $date))
            ->when($data['created_until'], 
                fn ($query, $date) => $query->whereDate('created_at', '<=', $date));
    })
```

### Actions

#### Action
```php
Action::make('activate')
    ->icon('heroicon-o-check')
    ->color('success')
    ->requiresConfirmation()
    ->modalHeading('Activate Product')
    ->modalDescription('Are you sure you want to activate this product?')
    ->modalSubmitActionLabel('Yes, activate')
    ->action(fn (Product $record) => $record->activate())
    ->visible(fn (Product $record): bool => !$record->is_active)
    ->disabled(fn (Product $record): bool => $record->is_locked)
```

#### BulkAction
```php
BulkAction::make('delete')
    ->requiresConfirmation()
    ->action(fn (Collection $records) => $records->each->delete())
    ->deselectRecordsAfterCompletion()
```

## Layout Components

### Grid & Section
```php
Forms\Components\Grid::make()
    ->schema([
        // Components
    ])
    ->columns([
        'sm' => 1,
        'md' => 2,
        'lg' => 3,
    ])

Forms\Components\Section::make('User Information')
    ->description('Enter the user details.')
    ->schema([
        // Components
    ])
    ->columns(2)
    ->collapsible()
    ->collapsed()
    ->persistCollapsed()
    ->compact()
```

### Tabs
```php
Forms\Components\Tabs::make('Tabs')
    ->tabs([
        Forms\Components\Tabs\Tab::make('General')
            ->schema([
                // Components
            ])
            ->icon('heroicon-o-information-circle'),
        Forms\Components\Tabs\Tab::make('Advanced')
            ->schema([
                // Components
            ])
            ->badge('New')
            ->badgeColor('success'),
    ])
    ->activeTab(1)
    ->persistTabInQueryString()
```

### Wizard
```php
Forms\Components\Wizard::make([
    Forms\Components\Wizard\Step::make('Details')
        ->description('Enter product details')
        ->schema([
            // Components
        ])
        ->icon('heroicon-o-clipboard-document-list'),
    Forms\Components\Wizard\Step::make('Pricing')
        ->schema([
            // Components
        ]),
    Forms\Components\Wizard\Step::make('Review')
        ->schema([
            // Components
        ]),
])
->startOnStep(1)
->skippable()
->persistStepInQueryString()
```

### Fieldset
```php
Forms\Components\Fieldset::make('Address')
    ->schema([
        TextInput::make('street'),
        TextInput::make('city'),
        TextInput::make('state'),
        TextInput::make('zip'),
    ])
    ->columns(2)
```

## Validation Rules

```php
TextInput::make('email')
    ->email()
    ->required()
    ->unique(ignoreRecord: true)
    ->confirmed() // Requires email_confirmation field
    ->same('password')
    ->different('username')
    ->gt('minimum_value')
    ->gte('minimum_value')
    ->lt('maximum_value')
    ->lte('maximum_value')
    ->minLength(3)
    ->maxLength(255)
    ->length(10)
    ->minValue(0)
    ->maxValue(100)
    ->regex('/^[A-Z]+$/i')
    ->alpha()
    ->alphaNum()
    ->ascii()
    ->in(['option1', 'option2'])
    ->notIn(['excluded1', 'excluded2'])
    ->exists('users', 'email')
    ->unique('users', 'email', ignoreRecord: true)
    ->rules(['custom_rule'])
    ->validationMessages([
        'required' => 'This field is required.',
    ])
```

## Relationships

### BelongsTo
```php
Select::make('user_id')
    ->relationship('user', 'name')
    ->searchable()
    ->preload()
    ->createOptionForm([
        TextInput::make('name')->required(),
        TextInput::make('email')->email()->required(),
    ])
    ->editOptionForm([
        TextInput::make('name')->required(),
        TextInput::make('email')->email()->required(),
    ])
```

### BelongsToMany
```php
Select::make('categories')
    ->multiple()
    ->relationship('categories', 'name')
    ->preload()
    ->pivotData([
        'is_primary' => true,
    ])
```

### HasMany (Repeater)
```php
Repeater::make('comments')
    ->relationship()
    ->schema([
        TextInput::make('author')->required(),
        Textarea::make('content')->required(),
        DateTimePicker::make('created_at'),
    ])
    ->defaultItems(0)
    ->reorderable('sort_order')
```

## Lifecycle Hooks

```php
TextInput::make('slug')
    ->afterStateHydrated(function (TextInput $component, $state) {
        // After the field is populated from the database
    })
    ->afterStateUpdated(function ($state, callable $set) {
        // After the field value changes
        $set('slug', Str::slug($state));
    })
    ->beforeStateDehydrated(function ($state) {
        // Before saving to database
        return Str::slug($state);
    })
    ->afterStateDehydrated(function () {
        // After saving to database
    })
```

## Conditional Logic

```php
Select::make('type')
    ->options([
        'individual' => 'Individual',
        'company' => 'Company',
    ])
    ->reactive()

TextInput::make('company_name')
    ->visible(fn (Get $get): bool => $get('type') === 'company')
    ->required(fn (Get $get): bool => $get('type') === 'company')

TextInput::make('tax_number')
    ->hidden(fn (Get $get): bool => $get('type') !== 'company')
    ->disabled(fn (Get $get): bool => !$get('is_taxable'))
```
