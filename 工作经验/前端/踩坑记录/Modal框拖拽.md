## Modal框拖拽



方案1：外面加一层使得外面可拖拽，

效果：拖拽实现，但是外面加一层影响了子元素相对父级的样式（modal组件都是全局蒙层加内部modal，拖拽层加在这两中间）
问题：内部传递的css高度和宽度使用百分比会相对新加层



方案2：

```
  className={cs(
        prefixCls,
        {
          [`${prefixCls}-simple`]: simple,
          [`${prefixCls}-rtl`]: rtl,
        },
        className
      )}
 
 style={{  display: draggable ? 'block' : null,  ...restStyle,  width: draggable ? '100%' : width,  height: draggable ? '100%' : height,}}
 
 draggable && title ? (
      <Draggable bounds="parent" handle={`.${prefixCls}-header`} {...draggableProps}>
        <div style={{ top: 0, verticalAlign: 'middle', display: 'inline-block', width, height }}>
          {modalWithMouseEventsDom}
        </div>
      </Draggable>
    ) : (
      modalWithMouseEventsDom
    );
```

把modal宽高定在百分百，外层使用预设宽高，先写calssname再写style覆盖





