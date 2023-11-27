## 文件结构

- `sysy.l`：词法分析器源代码。
- `sysy.y`：语法分析器和语义分析器源代码。
- `Makefile`：用于生成编译器的可执行文件的 Makefile。
- `tests/`：包含测试用例的目录，其中包括 `1.sy`、`2.sy`、`3.sy`、`4.sy` 和 `test.sy`。
- `test.sh`：测试脚本，用于编译和运行测试用例。

## 使用方法

1. 使用 `make` 命令生成编译器的可执行文件：

   ```
   make
   ```

2. 使用 `./sysy_compiler` 命令编译 SysY 源代码：

   ```
   ./sysy_compiler < input.sy > output.s
   ```

   其中，`input.sy` 是 SysY 源代码文件的路径，`output.s` 是生成的汇编代码文件的路径。

3. 使用 `gcc` 命令将汇编代码文件编译成可执行文件：

   ```
   gcc output.s -o output 
   ```

   其中，`output` 是生成的可执行文件的路径。

4. 运行可执行文件：

   ```
   ./output
   ```

## 测试
在使用 `make` 命令生成编译器的可执行文件后，可以使用 `test.sh` 脚本来编译和运行测试用例。该脚本支持以下命令行参数：

- `-a`：编译 `tests/` 目录下的所有 SysY 源代码文件。
- `-r <filename>`：编译并运行指定的 SysY 源代码文件。

例如，要编译并运行 `tests/1.sy` 文件，可以使用以下命令：

```
./test.sh -r 1.sy
```

该命令会将 `1.sy` 文件编译成汇编代码，并将汇编代码编译成可执行文件，最后运行可执行文件。