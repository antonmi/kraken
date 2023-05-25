# Kraken

**Flow-based Service Orchestration Framework**

Work in progress

## The idea
The core idea behind the Flow-based (FB) approach is to present the high-level logic
as a sequential transformation of the input data-structure to the output one.

Any interaction with the "system" is presented as "event" - arbitrary data-structure.
The input event goes through a set of connected components, each component performs some modification of the event, 
and, at the of the components' chain, one gets the output event, which represents the result of the interaction with the system.

Each component call underlying service in the system. The components are organized in "pipelines" - a tree (or graph) of connected components. Each pipeline corresponds to the specific "use-case" or "flow".

Imagine, in an online-shop one can have "user-service", "products-service", and "billing-service". One of the use-cases can be "user-orders-a-product".
The "event" of such interaction would be:
```json
{
    "type": "user-orders-a-product",
    "user_id": "user-123",
    "product_id": "product-456", 
}
```

The corresponding pipeline (simplified):
```json
[
    {
        "name": "find-user",
        "service": {"name": "user-service", "function": "find"}
    },
    {
        "name": "find-product",
        "service": {"name": "product-service", "function": "find"}
    },
    {
        "name": "finds-user",
        "service": {"name": "billing-service", "function": "bill"}
    }
]
```

So, the event goes through three components, each component calls underlying services.
After all the transformations, the output would be like:
```json
{
    "type": "user-orders-a-product",
    "success": "yes",
    "order_id": "789", 
}
```

The online-shop definitely has lots of other "use-cases" like:
"register-user", "login-user", "search-products", etc.
Each use-case has corresponding pipeline.

**Kraken** provides a simple DSL format for defining pipelines together with a runtime for executing the defined logic.

Under the hood **Kraken** uses: 
- the [ALF framework](https://github.com/antonmi/ALF) for building
pipelines of components (based on [Elixir GenStages](https://hexdocs.pm/gen_stage/GenStage.html)).
- the [Octopus](https://github.com/antonmi/octopus) library for defining intefaces to services in the system.

Therefore, it's important to have a basic understanding of the idea behind these two libraries

### ALF - Application Layer Framework
