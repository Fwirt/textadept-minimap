# Minimap

Minimap is a textadept module that helps you zoom out on your code and see the big picture.

Install this module by copying it into your ~/.textadept/modules/ directory or Textadept's modules/ directory.

![](./demo.png)

To add a minimap of the current view:

```lua
map = require("minimap")
map()
-- or map it to a keybinding
keys['cmd+M'] = function () map() end
```

Only one instance of minimap is needed to configure multiple minimap views, they should function independently from each other.

The minimap will track whatever buffer is open in its boss view, highlighting the currently visible lines.

Click on the minimap to jump to the corresponding section of the main buffer.

## Known bugs
- The boss view has to be focused to update the scrolled range in the minimap.
- The displayed range in the minimap "wobbles" due to tabs being... difficult to handle with virtual space.
- The boss view doesn't sync correctly when the buffer is changed yet. It can be fixed by unsplitting and resplitting.
