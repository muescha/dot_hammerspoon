# Info how to Use Events

# `.click()` vs `new Event('click')`

`.click()` also bubble up the DOM Tree while with `Event` I need to allow this bubble 

use `bubbles` and `terminates`:

```javascript
let clickEvent = new Event('click',
    {
        bubbles: true,
        cancelable: true,
    });
```

Source:
- https://developer.mozilla.org/en-US/docs/Web/Events/Creating_and_triggering_events

