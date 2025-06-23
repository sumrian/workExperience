# bun + webpack 配置环境变量

Windows：

```
"start:devops:common": "set NODE_ENV=common&& bun run --filter aptx-devops serve",
```

mac:

```
"start:devops:common": " NODE_ENV=common bun run --filter aptx-devops serve",
```

webpack:

```
const Envs = {};
dotenv.config({
  processEnv: Envs,
  path: path.resolve(process.cwd(), `.env.${process.env.NODE_ENV || 'dev'}`),
});
```

windows的set NODE_ENV=common&&不能写成set NODE_ENV=common && 这样webpack读取到的process.env.NODE_ENV是‘common ’在对应ENV.common文件里面匹配不上。mac正常