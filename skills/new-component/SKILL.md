---
name: new-component
description: Create a new React component following project conventions
disable-model-invocation: true
arguments:
  - name: name
    description: Component name (PascalCase)
    required: true
  - name: type
    description: Component type - poker (game components) or ui (primitives)
    default: poker
---

# New Component: {{name}}

Create a new React component at `src/components/{{type}}/{{name}}.tsx`.

## Requirements

1. **TypeScript**: Use explicit Props interface
2. **Imports**: Use `@/` path aliases
   - Types from `@/lib/types` or `@/lib/poker-types`
   - UI primitives from `@/components/ui/*`
3. **Styling**: Tailwind CSS classes only, no inline styles
4. **Export**: Named export (not default)

## Template

```tsx
import { cn } from '@/lib/utils';

type {{name}}Props = {
  className?: string;
  // Add props here
};

export const {{name}} = ({ className }: {{name}}Props) => {
  return (
    <div className={cn('', className)}>
      {/* Component content */}
    </div>
  );
};
```

## Checklist

- [ ] Props interface defined with explicit types
- [ ] Uses `cn()` for className merging if accepting className prop
- [ ] Follows existing component patterns in the same directory
- [ ] No default export
