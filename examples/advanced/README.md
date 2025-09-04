# Advanced Kustomize Concepts & Examples

This directory contains advanced Kustomize patterns and concepts that demonstrate expert-level usage. These examples build upon the foundational concepts in the main project.

## 📁 Contents

### 🔄 Variable Substitution & Replacements
- **`replacements.yaml`** - Modern variable substitution (replaces deprecated `vars`)
- **`variable-substitution.yaml`** - Advanced dynamic configuration patterns

### 🏗️ Architecture Patterns  
- **`multi-base.yaml`** - Composing multiple base configurations
- **`plugins.yaml`** - Plugin system demonstration

### 🛡️ Validation & Quality
- **`openapi-validation.yaml`** - OpenAPI schema validation examples
- **`transformers.yaml`** - Advanced built-in transformers

## 🎯 Learning Objectives

After studying these examples, you'll understand:

1. **Advanced Variable Management** - Dynamic configuration across environments
2. **Complex Composition** - Multi-base and multi-component patterns  
3. **Plugin Architecture** - Extending Kustomize functionality
4. **Validation Strategies** - Schema and policy validation
5. **Performance Optimization** - Large-scale deployment patterns

## 🚀 Usage Examples

### Testing Variable Substitution

```bash
# Preview replacements in action
kubectl kustomize examples/advanced/ --enable-alpha-plugins

# See how variables are substituted
grep -A 10 "replacements:" examples/advanced/replacements.yaml
```

### Multi-Base Composition

```bash
# Understand multi-base resource resolution
kubectl kustomize examples/advanced/ | grep -E "(name:|namespace:|kind:)"

# See the composition hierarchy
tree -I '__pycache__|*.pyc' examples/advanced/
```

### Plugin Development

```bash
# Enable plugin support (requires Kustomize v5.0+)
export KUSTOMIZE_PLUGIN_HOME=~/.config/kustomize/plugin
mkdir -p $KUSTOMIZE_PLUGIN_HOME

# Test plugin functionality
kubectl kustomize examples/advanced/ --enable-alpha-plugins --load_restrictor=LoadRestrictionsNone
```

## 🔧 Advanced Patterns Explained

### 1. Replacements vs Variables

**Old Way (Deprecated `vars`):**
```yaml
vars:
- name: SERVICE_NAME
  objref:
    kind: Service
    name: web-app-service
    apiVersion: v1
  fieldref:
    fieldpath: metadata.name
```

**New Way (`replacements`):**
```yaml
replacements:
- source:
    kind: Service
    name: web-app-service
    fieldPath: metadata.name
  targets:
  - select:
      kind: ConfigMap
    fieldPaths:
    - data.service_name
```

### 2. Multi-Base Coordination

```yaml
# Coordinate resources across multiple bases
resources:
- ../../base/                    # Application base
- ../../../infrastructure/base/  # Infrastructure base  
- ../../../security/base/        # Security base

# Use replacements to coordinate values between bases
replacements:
- source:
    kind: Service
    name: web-app-service        # From application base
  targets:
  - select:
      kind: Ingress
      name: shared-ingress       # In infrastructure base
```

### 3. Advanced Transformers

```yaml
# Chain multiple transformers for complex modifications
transformers:
- prefix-suffix-transformer.yaml    # Naming
- label-transformer.yaml           # Labeling  
- annotation-transformer.yaml     # Metadata
- replica-transformer.yaml        # Scaling
- image-transformer.yaml          # Container images
```

### 4. Plugin Architecture

```yaml
# Custom plugins for specialized logic
generators:
- secretProviderClass.yaml         # Azure Key Vault integration
- customConfigMap.yaml            # Environment-specific config

transformers:  
- complianceTransformer.yaml      # Regulatory compliance
- securityTransformer.yaml        # Security hardening
```

## 🎓 Best Practices for Advanced Usage

### 1. **Replacements Strategy**
- Use for dynamic cross-resource references
- Prefer over complex patches for value sharing
- Document replacement chains clearly

### 2. **Multi-Base Design**
- Keep bases loosely coupled
- Use clear dependency ordering
- Document composition strategy

### 3. **Plugin Development**
- Start with built-in transformers
- Create plugins for repeated custom logic
- Test plugins thoroughly in isolation

### 4. **Validation Integration**
- Implement schema validation early
- Use policy validation for compliance
- Automate validation in CI/CD

### 5. **Performance Considerations**
- Profile large kustomizations
- Use `--load_restrictor=LoadRestrictionsNone` carefully
- Monitor build times and optimize

## 🚨 Common Advanced Pitfalls

### ❌ Avoid These Patterns

```yaml
# DON'T: Overly complex replacement chains
replacements:
- source: {...}
  targets:
  - select: {...}
    fieldPaths: [a, b, c, d, e, f]  # Too many targets

# DON'T: Circular dependencies in multi-base
resources:
- base-a/  
- base-b/  # which references base-a/
```

### ✅ Prefer These Patterns

```yaml
# DO: Simple, clear replacements
replacements:
- source: {...}
  targets:
  - select: {...}
    fieldPaths: [specific.field]

# DO: Linear dependency chains
resources:
- infrastructure/base/  # No dependencies
- application/base/     # Depends on infrastructure
- security/base/        # Depends on both
```

## 🔗 Related Resources

- [Kustomize Plugin Documentation](https://kubectl.docs.kubernetes.io/guides/extending_kustomize/)
- [Replacements vs Vars](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/vars-deprecated/README.md)
- [Multi-Base Patterns](https://github.com/kubernetes-sigs/kustomize/tree/master/examples/multiple-bases)
- [OpenAPI Integration](https://kubectl.docs.kubernetes.io/guides/config_management/validation/)

---

🎯 **Next Steps**: Practice these patterns in your own projects, starting with simple replacements and building up to multi-base compositions. Remember: advanced patterns should solve real problems, not add complexity for its own sake.
