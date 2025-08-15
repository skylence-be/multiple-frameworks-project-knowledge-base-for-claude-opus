# Ecosystem Tools & Essential Packages

## Development Tools

### Code Editors & IDEs
```json
// .vscode/settings.json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true,
    "source.organizeImports": true
  },
  "editor.rulers": [80, 120],
  "editor.snippetSuggestions": "top",
  "files.exclude": {
    "**/node_modules": true,
    "**/dist": true,
    "**/.git": true
  },
  "typescript.preferences.importModuleSpecifier": "relative",
  "typescript.updateImportsOnFileMove.enabled": "always",
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}

// .vscode/extensions.json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "christian-kohler.path-intellisense",
    "formulahendry.auto-rename-tag",
    "burkeholland.simple-react-snippets",
    "dsznajder.es7-react-js-snippets",
    "bradlc.vscode-tailwindcss",
    "Prisma.prisma"
  ]
}
```

### Browser Extensions
```markdown
## Essential Browser DevTools

### Chrome/Edge Extensions
- React Developer Tools
- Vue.js devtools
- Redux DevTools
- Angular DevTools
- Lighthouse
- Wappalyzer (tech stack detector)
- JSON Viewer
- EditThisCookie
- CORS Unblock (dev only!)
- Responsive Viewer

### Performance Tools
- Web Vitals Extension
- Performance Monitor
- Network Throttling
```

## Build Tools

### Webpack Configuration
```javascript
// webpack.config.js - Modern setup
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const TerserPlugin = require('terser-webpack-plugin');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');

module.exports = (env, argv) => {
  const isDev = argv.mode === 'development';
  
  return {
    entry: './src/index.js',
    output: {
      path: path.resolve(__dirname, 'dist'),
      filename: isDev ? '[name].js' : '[name].[contenthash].js',
      clean: true
    },
    
    module: {
      rules: [
        {
          test: /\.(js|jsx|ts|tsx)$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              presets: [
                '@babel/preset-env',
                '@babel/preset-react',
                '@babel/preset-typescript'
              ]
            }
          }
        },
        {
          test: /\.css$/,
          use: [
            isDev ? 'style-loader' : MiniCssExtractPlugin.loader,
            'css-loader',
            'postcss-loader'
          ]
        },
        {
          test: /\.(png|svg|jpg|jpeg|gif)$/i,
          type: 'asset/resource'
        }
      ]
    },
    
    plugins: [
      new HtmlWebpackPlugin({
        template: './public/index.html'
      }),
      !isDev && new MiniCssExtractPlugin({
        filename: '[name].[contenthash].css'
      })
    ].filter(Boolean),
    
    optimization: {
      minimize: !isDev,
      minimizer: [
        new TerserPlugin(),
        new CssMinimizerPlugin()
      ],
      splitChunks: {
        chunks: 'all'
      }
    },
    
    devServer: {
      port: 3000,
      hot: true,
      open: true,
      historyApiFallback: true
    }
  };
};
```

### Vite Configuration
```javascript
// vite.config.js - Fast alternative
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [
    react(),
    visualizer({
      open: true,
      gzipSize: true,
      brotliSize: true
    })
  ],
  
  resolve: {
    alias: {
      '@': '/src',
      '@components': '/src/components',
      '@utils': '/src/utils'
    }
  },
  
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true
      }
    }
  },
  
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          utils: ['lodash', 'date-fns']
        }
      }
    }
  }
});
```

## Testing Tools

### Jest Configuration
```javascript
// jest.config.js
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/src/setupTests.js'],
  
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '\\.(css|less|scss|sass)$': 'identity-obj-proxy',
    '\\.(jpg|jpeg|png|gif|svg)$': '<rootDir>/__mocks__/fileMock.js'
  },
  
  collectCoverageFrom: [
    'src/**/*.{js,jsx,ts,tsx}',
    '!src/index.js',
    '!src/**/*.d.ts',
    '!src/**/*.stories.js'
  ],
  
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  
  transform: {
    '^.+\\.(js|jsx|ts|tsx)$': 'babel-jest'
  }
};
```

### Cypress Configuration
```javascript
// cypress.config.js
const { defineConfig } = require('cypress');

module.exports = defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    viewportWidth: 1280,
    viewportHeight: 720,
    video: true,
    screenshotOnRunFailure: true,
    
    setupNodeEvents(on, config) {
      // Task for database seeding
      on('task', {
        'db:seed': () => {
          // Seed database
          return null;
        },
        'db:clear': () => {
          // Clear database
          return null;
        }
      });
    }
  },
  
  component: {
    devServer: {
      framework: 'react',
      bundler: 'webpack'
    }
  }
});
```

## State Management Libraries

### Redux Toolkit Setup
```javascript
// store/store.js
import { configureStore } from '@reduxjs/toolkit';
import { setupListeners } from '@reduxjs/toolkit/query';
import userReducer from './slices/userSlice';
import { apiSlice } from './slices/apiSlice';

export const store = configureStore({
  reducer: {
    user: userReducer,
    [apiSlice.reducerPath]: apiSlice.reducer
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware().concat(apiSlice.middleware),
  devTools: process.env.NODE_ENV !== 'production'
});

setupListeners(store.dispatch);

// RTK Query API slice
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';

export const apiSlice = createApi({
  reducerPath: 'api',
  baseQuery: fetchBaseQuery({
    baseUrl: '/api',
    prepareHeaders: (headers, { getState }) => {
      const token = getState().auth.token;
      if (token) {
        headers.set('authorization', `Bearer ${token}`);
      }
      return headers;
    }
  }),
  tagTypes: ['User', 'Post'],
  endpoints: (builder) => ({
    getUsers: builder.query({
      query: () => '/users',
      providesTags: ['User']
    }),
    createUser: builder.mutation({
      query: (user) => ({
        url: '/users',
        method: 'POST',
        body: user
      }),
      invalidatesTags: ['User']
    })
  })
});

export const { useGetUsersQuery, useCreateUserMutation } = apiSlice;
```

### Zustand Setup
```javascript
// stores/useStore.js
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

const useStore = create(
  devtools(
    persist(
      (set, get) => ({
        // State
        user: null,
        todos: [],
        
        // Actions
        setUser: (user) => set({ user }),
        
        addTodo: (todo) => set((state) => ({
          todos: [...state.todos, { id: Date.now(), ...todo }]
        })),
        
        removeTodo: (id) => set((state) => ({
          todos: state.todos.filter(t => t.id !== id)
        })),
        
        // Computed
        get completedTodos() {
          return get().todos.filter(t => t.completed);
        }
      }),
      {
        name: 'app-storage',
        partialize: (state) => ({ user: state.user })
      }
    ),
    {
      name: 'app-store'
    }
  )
);

export default useStore;
```

## UI Component Libraries

### Popular Component Libraries
```javascript
// Material-UI (MUI) Setup
import { createTheme, ThemeProvider } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#1976d2'
    },
    secondary: {
      main: '#dc004e'
    }
  },
  typography: {
    fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
    h1: {
      fontSize: '2.5rem'
    }
  }
});

// Ant Design Setup
import { ConfigProvider } from 'antd';
import 'antd/dist/reset.css';

<ConfigProvider
  theme={{
    token: {
      colorPrimary: '#00b96b',
      borderRadius: 2
    }
  }}
>
  <App />
</ConfigProvider>

// Chakra UI Setup
import { ChakraProvider, extendTheme } from '@chakra-ui/react';

const theme = extendTheme({
  colors: {
    brand: {
      900: '#1a365d',
      800: '#153e75',
      700: '#2a69ac'
    }
  }
});
```

## API & Backend Tools

### Express Middleware Stack
```javascript
// Essential Express middleware
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const mongoSanitize = require('express-mongo-sanitize');

const app = express();

// Security
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(','),
  credentials: true
}));

// Rate limiting
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
}));

// Data parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(mongoSanitize());

// Compression
app.use(compression());

// Logging
app.use(morgan('combined'));
```

### Database ORMs/ODMs
```javascript
// Prisma Setup
// schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

// Sequelize Setup
const { Sequelize, DataTypes } = require('sequelize');

const sequelize = new Sequelize(process.env.DATABASE_URL, {
  logging: false,
  pool: {
    max: 5,
    min: 0,
    acquire: 30000,
    idle: 10000
  }
});

const User = sequelize.define('User', {
  email: {
    type: DataTypes.STRING,
    unique: true,
    allowNull: false
  },
  name: DataTypes.STRING
});

// Mongoose Setup
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true
  },
  name: String,
  createdAt: {
    type: Date,
    default: Date.now
  }
});

const User = mongoose.model('User', userSchema);
```

## Utility Libraries

### Essential NPM Packages
```javascript
// Package recommendations by category

const essentialPackages = {
  utilities: [
    'lodash',        // Utility functions
    'date-fns',      // Date manipulation
    'uuid',          // UUID generation
    'classnames',    // Conditional classes
    'qs',            // Query string parsing
  ],
  
  validation: [
    'joi',           // Schema validation
    'yup',           // Object schema validation
    'validator',     // String validators
    'zod',           // TypeScript-first validation
  ],
  
  http: [
    'axios',         // HTTP client
    'ky',            // Modern fetch wrapper
    'got',           // Node.js HTTP client
  ],
  
  forms: [
    'react-hook-form',  // React forms
    'formik',           // Form management
    'react-select',     // Select component
  ],
  
  authentication: [
    'jsonwebtoken',     // JWT
    'bcrypt',           // Password hashing
    'passport',         // Auth middleware
    'express-session',  // Session management
  ],
  
  development: [
    'nodemon',          // Auto-restart
    'concurrently',     // Run multiple commands
    'cross-env',        // Cross-platform env vars
    'dotenv',           // Environment variables
    'chalk',            // Terminal colors
  ],
  
  testing: [
    '@testing-library/react',
    '@testing-library/jest-dom',
    'msw',              // Mock service worker
    'faker',            // Test data generation
    'supertest',        // API testing
  ]
};
```

## CLI Tools

### Custom CLI Setup
```javascript
#!/usr/bin/env node
// cli.js

const { program } = require('commander');
const inquirer = require('inquirer');
const chalk = require('chalk');
const ora = require('ora');

program
  .version('1.0.0')
  .description('Project CLI tool');

program
  .command('generate <type>')
  .alias('g')
  .description('Generate component/service/module')
  .action(async (type) => {
    const spinner = ora('Generating...').start();
    
    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'name',
        message: `${type} name:`,
        validate: (input) => input.length > 0
      }
    ]);
    
    // Generation logic
    spinner.succeed(chalk.green(`${type} generated!`));
  });

program.parse(process.argv);
```

## Monitoring & Analytics

### Application Monitoring
```javascript
// Sentry setup
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: process.env.REACT_APP_SENTRY_DSN,
  integrations: [
    new Sentry.BrowserTracing(),
    new Sentry.Replay()
  ],
  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
});

// Google Analytics
import ReactGA from 'react-ga4';

ReactGA.initialize(process.env.REACT_APP_GA_ID);
ReactGA.send('pageview');

// Custom analytics wrapper
class Analytics {
  static track(event, properties) {
    // Google Analytics
    ReactGA.event({
      category: properties.category,
      action: event,
      label: properties.label,
      value: properties.value
    });
    
    // Mixpanel
    if (window.mixpanel) {
      window.mixpanel.track(event, properties);
    }
    
    // Custom backend
    fetch('/api/analytics', {
      method: 'POST',
      body: JSON.stringify({ event, properties })
    });
  }
}
```

## Essential Package List by Framework

### React Ecosystem
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.8.0",
    "@tanstack/react-query": "^4.24.0",
    "zustand": "^4.3.0",
    "react-hook-form": "^7.43.0",
    "@emotion/react": "^11.10.0",
    "framer-motion": "^10.0.0"
  }
}
```

### Vue Ecosystem
```json
{
  "dependencies": {
    "vue": "^3.3.0",
    "vue-router": "^4.2.0",
    "pinia": "^2.1.0",
    "@vueuse/core": "^10.0.0",
    "vee-validate": "^4.9.0",
    "@tanstack/vue-query": "^4.29.0"
  }
}
```

### Node.js Backend
```json
{
  "dependencies": {
    "express": "^4.18.0",
    "fastify": "^4.17.0",
    "prisma": "^4.13.0",
    "bull": "^4.10.0",
    "ioredis": "^5.3.0",
    "winston": "^3.8.0",
    "celebrate": "^15.0.0"
  }
}
```
