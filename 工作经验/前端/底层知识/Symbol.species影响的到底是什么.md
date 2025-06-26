## Symbol.species影响的到底是什么



阅读JavaScript第四版了解到：

![75082082635](C:\Users\YangTeng\AppData\Local\Temp\1750820826359.png)

## 思维发散

所有的不修改原数组的方法都会受到影响吗

## 测试

```
 class MyArray extends Array {
        static get [Symbol.species]() {
          return function () {
            return [1, 2, 3];
          };
        }
      }
      const myArray = new MyArray();
      const sorted = myArray.toSorted();
      const map = myArray.map(() => {});
      console.log(myArray); // MyArray []
      console.log(sorted); // []
      console.log(map); // [1,2,3]
```

并不是toSorted没有被影响，

## 调研

### toSorted

![75082097691](C:\Users\YangTeng\AppData\Local\Temp\1750820976918.png)

注意到第四行根据读取到的len创建数组，没有发现什么猫腻，对照打开filter

### filter

![75082111602](C:\Users\YangTeng\AppData\Local\Temp\1750821116026.png)

发现了猫腻，同样第四行使用的是[ArraySpeciesCreate](https://tc39.es/ecma262/#sec-arrayspeciescreate)，那么区别应该是这里

### [ArraySpeciesCreate](https://tc39.es/ecma262/#sec-arrayspeciescreate)

![75082122411](C:\Users\YangTeng\AppData\Local\Temp\1750821224113.png)

第五行去读取 [%Symbol.species%](https://tc39.es/ecma262/#sec-well-known-symbols)

### %Symbol.species%

![75082130981](C:\Users\YangTeng\AppData\Local\Temp\1750821309814.png)

![75082138459](C:\Users\YangTeng\AppData\Local\Temp\1750821384595.png)

## 结论

只有直接间接   a. Set C to ? [Get](#sec-get-o-p)(C, [%Symbol.species%](#sec-well-known-symbols)).才会受影响，未全部测试，要使用时候再翻文档