---
title: 算法核心题学习指南（Java）
date: 2020-08-03 22:35:04
tags: 算法
top: 9
---

## 使用方式（Java）
- 设定固定解题上限；卡住时先提炼思路，再关掉题解重写一遍
- 每题记录：类型 + 核心不变量 + 边界用例 + 复杂度
- 复盘：对错题做分层回看并闭卷重写
- 说明：本文主路径覆盖 Hot100 的核心 56 题；文末保留 Hot100 全量 100 题记录模板

## 核心学习路径（Hot100 核心 56 题）

建议循环三件事：
1) 新题 4 题（按当前模块顺序完成）
2) 复盘 1 题（优先重做最近卡住或出错的题）
3) 工程练习 1 题（按下方插入点推进）

新题模块（14 组）：
- 模块 1（哈希/前缀和）：[1 两数之和](#lc1)、[49 字母异位词分组](#lc49)、[128 最长连续序列](#lc128)、[560 和为 K 的子数组](#lc560)
- 模块 2（滑动窗口/双指针）：[3 无重复字符的最长子串](#lc3)、[76 最小覆盖子串](#lc76)、[438 找到字符串中所有字母异位词](#lc438)、[11 盛最多水的容器](#lc11)
- 模块 3（数组/双指针）：[15 三数之和](#lc15)、[75 颜色分类](#lc75)、[283 移动零](#lc283)、[287 寻找重复数](#lc287)
- 模块 4（栈/单调）：[20 有效的括号](#lc20)、[739 每日温度](#lc739)、[394 字符串解码](#lc394)、[42 接雨水](#lc42)
- 模块 5（二分/矩阵/前缀）：[33 搜索旋转排序数组](#lc33)、[34 在排序数组中查找元素的第一个和最后一个位置](#lc34)、[240 搜索二维矩阵 II](#lc240)、[238 除了自身以外数组的乘积](#lc238)
- 模块 6（区间/堆）：[56 合并区间](#lc56)、[215 数组中的第K个最大元素](#lc215)、[253 会议室 II](#lc253)、[347 前 K 个高频元素](#lc347)
- 模块 7（链表基础）：[19 删除链表的倒数第 N 个结点](#lc19)、[21 合并两个有序链表](#lc21)、[141 环形链表](#lc141)、[206 反转链表](#lc206)
- 模块 8（树基础）：[102 二叉树的层序遍历](#lc102)、[104 二叉树的最大深度](#lc104)、[101 对称二叉树](#lc101)、[226 翻转二叉树](#lc226)
- 模块 9（树进阶/树DP）：[105 从前序与中序遍历序列构造二叉树](#lc105)、[236 二叉树的最近公共祖先](#lc236)、[337 打家劫舍 III](#lc337)、[543 二叉树的直径](#lc543)
- 模块 10（DP 核心）：[70 爬楼梯](#lc70)、[198 打家劫舍](#lc198)、[322 零钱兑换](#lc322)、[300 最长递增子序列](#lc300)
- 模块 11（DP/字符串）：[53 最大子数组和](#lc53)、[121 买卖股票的最佳时机](#lc121)、[309 买卖股票的最佳时机含冷冻期](#lc309)、[139 单词拆分](#lc139)
- 模块 12（回溯基础）：[17 电话号码的字母组合](#lc17)、[22 括号生成](#lc22)、[39 组合总和](#lc39)、[46 全排列](#lc46)
- 模块 13（回溯 + 难点）：[78 子集](#lc78)、[79 单词搜索](#lc79)、[239 滑动窗口最大值](#lc239)、[5 最长回文子串](#lc5)
- 模块 14（设计 + 图）：[146 LRU 缓存](#lc146)、[208 实现 Trie (前缀树)](#lc208)、[200 岛屿数量](#lc200)、[207 课程表](#lc207)

工程练习插入点（每完成 2 个模块插入 1 个）：
- 模块 2 后：LRU Cache
- 模块 4 后：阻塞队列：生产者-消费者
- 模块 6 后：重试器：指数退避 + 最大次数 + 可取消
- 模块 8 后：限流器：Token Bucket
- 模块 10 后：带超时的缓存：LRU + TTL
- 模块 12 后：Debounce/Throttle
- 模块 14 后：线程安全单例：双检锁

## 附录：工程练习题（Java）

在实际开发类编码训练中，经常会遇到“写个类/写个工具”这类题。建议至少能写出核心版本，并说明线程安全和复杂度。

- [ ] LRU Cache（可先写非线程安全；再说怎么加锁/分段锁/读写锁）
- [ ] 带超时的缓存：LRU + TTL（如何处理过期清理、惰性删除）
- [ ] 阻塞队列：生产者-消费者（`ReentrantLock` + `Condition` 或 `wait/notify`）
- [ ] 重试器：指数退避 + 最大次数 + 可取消（线程中断语义）
- [ ] 限流器：Token Bucket（时间推进、并发安全）
- [ ] Debounce/Throttle（`ScheduledExecutorService`，支持取消）
- [ ] 线程安全单例：双检锁（`volatile` + `synchronized`，解释内存可见性）

## 解题记录（按学习节奏顺序）

<a id='lc1'></a>
### LC 1：两数之和
题目链接：https://leetcode.cn/problems/two-sum/  
类型：哈希/前缀和/计数  
难度：Easy  
状态：DONE  
要点：
复杂度：

```java
class Solution {
    public int[] twoSum(int[] nums, int target) {
        int[] result = new int[2];

        Map<Integer,Integer> map = new HashMap<>();
        for (int i = 0; i < nums.length; i++) {
            if(map.containsKey(target-nums[i])){
               int value = map.get(target-nums[i]);
               result[0] = value;
               result[1] = i;
               break;
            }
            map.put(nums[i],i);
        }

        return result;
        
    }
}
```

<a id='lc49'></a>
### LC 49：字母异位词分组
题目链接：https://leetcode.cn/problems/group-anagrams/  
类型：哈希/前缀和/计数  
难度：Medium  
状态：DONE  
要点：
复杂度：

```java
class Solution {
    public List<List<String>> groupAnagrams(String[] strs) {
        List<List<String>> result = new ArrayList<>();
        HashMap<String,ArrayList<Integer>> map = new HashMap<>();
        for (int i = 0; i < strs.length; i++) {
            char[] arr = strs[i].toCharArray();
            Arrays.sort(arr); // 升序（按 Unicode 编码）
            String sorted = new String(arr); // "abcd"
            ArrayList<Integer> tmp = map.getOrDefault(sorted, new ArrayList<>());
            tmp.add(i);
            map.put(sorted, tmp);
        }
        for (String keySet : map.keySet()) {
            List<String> tmp = new ArrayList<>();
            ArrayList<Integer>  value = map.get(keySet);
            for(int i = 0; i< value.size();i++){
                int index = value.get(i);
                tmp.add(strs[index]);
            }
            result.add(tmp);
        }

        return result;
    }
}
```

<a id='lc128'></a>
### LC 128：最长连续序列
题目链接：https://leetcode.cn/problems/longest-consecutive-sequence/  
类型：哈希/前缀和/计数  
难度：Medium  
状态：DONE  
要点：
复杂度：

```java
class Solution {
    public int longestConsecutive(int[] nums) {
        if(nums.length == 0){
            return 0;
        }
        Arrays.sort(nums);
        int max = 0;
        int n = 0;
        for (int i = 0; i < nums.length - 1; i++) {
            int a = nums[i];
            int b = nums[i + 1];
            if (b - a == 1) {
                n++;
                max = Math.max(max, n);
            } else if (b == a) {
            } else {
                n = 0;
            }
        }
        return max + 1;
    }
}
```

<a id='lc560'></a>
### LC 560：和为 K 的子数组
题目链接：https://leetcode.cn/problems/subarray-sum-equals-k/  
类型：哈希/前缀和/计数  
难度：Medium  
状态：DONE  
要点：
复杂度：

```java
class Solution {
    public int subarraySum(int[] nums, int k) {
        int pre = 0;
        int ans = 0;
        HashMap<Integer, Integer> map = new HashMap<>();
        map.put(0, 1);
        for (int i = 0; i < nums.length; i++) {
            pre += nums[i];
            if (map.containsKey(pre - k)) {
                ans += map.get(pre - k);
            }
            map.put(pre, map.getOrDefault(pre, 0) + 1);
        }
        return ans;
    }
}
```

<a id='lc3'></a>
### LC 3：无重复字符的最长子串
题目链接：https://leetcode.cn/problems/longest-substring-without-repeating-characters/  
类型：滑动窗口  
难度：Medium  
状态：DONE  
要点：s
复杂度：

```java
class Solution {
    public static int lengthOfLongestSubstring(String s) {

        HashMap<Character, Integer> last = new HashMap<>();

        char[] arr = s.toCharArray();
        int max = 0;
        int left = 0;

        for (int right = 0; right < arr.length; right++) {
            char a = arr[right];
            if (last.containsKey(a) && last.get(a) >= left) {
                left = last.get(a) + 1;
            }
            last.put(a, right);
            max = Math.max(max, right - left + 1);
        }
        return max;
    }
}
```

<a id='lc76'></a>
### LC 76：最小覆盖子串
题目链接：https://leetcode.cn/problems/minimum-window-substring/  
类型：滑动窗口  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc438'></a>
### LC 438：找到字符串中所有字母异位词
题目链接：https://leetcode.cn/problems/find-all-anagrams-in-a-string/  
类型：滑动窗口  
难度：Medium  
状态：DONE  
要点：
复杂度：

```java
class Solution {
    public List<Integer> findAnagrams(String s, String p) {
        List<Integer> result = new ArrayList<>();

        char[] sArr = s.toCharArray();
        char[] pArr = p.toCharArray();

        if (sArr.length < pArr.length) {
            return result;
        }

        Arrays.sort(pArr);
        String tp = new String(pArr);

        int pLen = pArr.length;

        for (int i = 0; i <= sArr.length - pLen; i++) {
            String ts = s.substring(i, i + pLen);
            char[] tsArr = ts.toCharArray();
            Arrays.sort(tsArr);
            String tempS = new String(tsArr);
            if (tempS.equals(tp)) {
                result.add(i);
            }
        }

        return result;
    }
}
```

<a id='lc11'></a>
### LC 11：盛最多水的容器
题目链接：https://leetcode.cn/problems/container-with-most-water/  
类型：双指针/数组技巧  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
class Solution {
    public int maxArea(int[] height) {
        int max = 0;

        int l = 0;
        int r = height.length - 1;

        while (l < r) {
            int area = Math.min(height[l], height[r]) * (r - l);
            max = Math.max(max, area);
            if (height[l] <= height[r]) {
                ++l;
            } else {
                --r;
            }
        }
        return max;
    }
}
```

<a id='lc15'></a>
### LC 15：三数之和
题目链接：https://leetcode.cn/problems/3sum/  
类型：双指针/数组技巧  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc75'></a>
### LC 75：颜色分类
题目链接：https://leetcode.cn/problems/sort-colors/  
类型：双指针/数组技巧  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc283'></a>
### LC 283：移动零
题目链接：https://leetcode.cn/problems/move-zeroes/  
类型：双指针/数组技巧  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc287'></a>
### LC 287：寻找重复数
题目链接：https://leetcode.cn/problems/find-the-duplicate-number/  
类型：双指针/数组技巧  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc20'></a>
### LC 20：有效的括号
题目链接：https://leetcode.cn/problems/valid-parentheses/  
类型：栈/单调结构  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc739'></a>
### LC 739：每日温度
题目链接：https://leetcode.cn/problems/daily-temperatures/  
类型：栈/单调结构  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc394'></a>
### LC 394：字符串解码
题目链接：https://leetcode.cn/problems/decode-string/  
类型：栈/单调结构  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc42'></a>
### LC 42：接雨水
题目链接：https://leetcode.cn/problems/trapping-rain-water/  
类型：栈/单调结构  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc33'></a>
### LC 33：搜索旋转排序数组
题目链接：https://leetcode.cn/problems/search-in-rotated-sorted-array/  
类型：二分/分治/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc34'></a>
### LC 34：在排序数组中查找元素的第一个和最后一个位置
题目链接：https://leetcode.cn/problems/find-first-and-last-position-of-element-in-sorted-array/  
类型：二分/分治/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc240'></a>
### LC 240：搜索二维矩阵 II
题目链接：https://leetcode.cn/problems/search-a-2d-matrix-ii/  
类型：二分/分治/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc238'></a>
### LC 238：除了自身以外数组的乘积
题目链接：https://leetcode.cn/problems/product-of-array-except-self/  
类型：哈希/前缀和/计数  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc56'></a>
### LC 56：合并区间
题目链接：https://leetcode.cn/problems/merge-intervals/  
类型：贪心/区间/排序  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc215'></a>
### LC 215：数组中的第K个最大元素
题目链接：https://leetcode.cn/problems/kth-largest-element-in-an-array/  
类型：堆/优先队列  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc253'></a>
### LC 253：会议室 II
题目链接：https://leetcode.cn/problems/meeting-rooms-ii/  
类型：堆/优先队列  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc347'></a>
### LC 347：前 K 个高频元素
题目链接：https://leetcode.cn/problems/top-k-frequent-elements/  
类型：堆/优先队列  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc19'></a>
### LC 19：删除链表的倒数第 N 个结点
题目链接：https://leetcode.cn/problems/remove-nth-node-from-end-of-list/  
类型：链表  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc21'></a>
### LC 21：合并两个有序链表
题目链接：https://leetcode.cn/problems/merge-two-sorted-lists/  
类型：链表  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc141'></a>
### LC 141：环形链表
题目链接：https://leetcode.cn/problems/linked-list-cycle/  
类型：链表  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc206'></a>
### LC 206：反转链表
题目链接：https://leetcode.cn/problems/reverse-linked-list/  
类型：链表  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc102'></a>
### LC 102：二叉树的层序遍历
题目链接：https://leetcode.cn/problems/binary-tree-level-order-traversal/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc104'></a>
### LC 104：二叉树的最大深度
题目链接：https://leetcode.cn/problems/maximum-depth-of-binary-tree/  
类型：树  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc101'></a>
### LC 101：对称二叉树
题目链接：https://leetcode.cn/problems/symmetric-tree/  
类型：树  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc226'></a>
### LC 226：翻转二叉树
题目链接：https://leetcode.cn/problems/invert-binary-tree/  
类型：树  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc105'></a>
### LC 105：从前序与中序遍历序列构造二叉树
题目链接：https://leetcode.cn/problems/construct-binary-tree-from-preorder-and-inorder-traversal/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc236'></a>
### LC 236：二叉树的最近公共祖先
题目链接：https://leetcode.cn/problems/lowest-common-ancestor-of-a-binary-tree/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc337'></a>
### LC 337：打家劫舍 III
题目链接：https://leetcode.cn/problems/house-robber-iii/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc543'></a>
### LC 543：二叉树的直径
题目链接：https://leetcode.cn/problems/diameter-of-binary-tree/  
类型：树  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc70'></a>
### LC 70：爬楼梯
题目链接：https://leetcode.cn/problems/climbing-stairs/  
类型：动态规划  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc198'></a>
### LC 198：打家劫舍
题目链接：https://leetcode.cn/problems/house-robber/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc322'></a>
### LC 322：零钱兑换
题目链接：https://leetcode.cn/problems/coin-change/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc300'></a>
### LC 300：最长递增子序列
题目链接：https://leetcode.cn/problems/longest-increasing-subsequence/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc53'></a>
### LC 53：最大子数组和
题目链接：https://leetcode.cn/problems/maximum-subarray/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc121'></a>
### LC 121：买卖股票的最佳时机
题目链接：https://leetcode.cn/problems/best-time-to-buy-and-sell-stock/  
类型：贪心/区间/排序  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc309'></a>
### LC 309：买卖股票的最佳时机含冷冻期
题目链接：https://leetcode.cn/problems/best-time-to-buy-and-sell-stock-with-cooldown/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc139'></a>
### LC 139：单词拆分
题目链接：https://leetcode.cn/problems/word-break/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc17'></a>
### LC 17：电话号码的字母组合
题目链接：https://leetcode.cn/problems/letter-combinations-of-a-phone-number/  
类型：回溯/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc22'></a>
### LC 22：括号生成
题目链接：https://leetcode.cn/problems/generate-parentheses/  
类型：回溯/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc39'></a>
### LC 39：组合总和
题目链接：https://leetcode.cn/problems/combination-sum/  
类型：回溯/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc46'></a>
### LC 46：全排列
题目链接：https://leetcode.cn/problems/permutations/  
类型：回溯/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc78'></a>
### LC 78：子集
题目链接：https://leetcode.cn/problems/subsets/  
类型：回溯/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc79'></a>
### LC 79：单词搜索
题目链接：https://leetcode.cn/problems/word-search/  
类型：回溯/搜索  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc239'></a>
### LC 239：滑动窗口最大值
题目链接：https://leetcode.cn/problems/sliding-window-maximum/  
类型：栈/单调结构  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc5'></a>
### LC 5：最长回文子串
题目链接：https://leetcode.cn/problems/longest-palindromic-substring/  
类型：双指针/数组技巧  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc146'></a>
### LC 146：LRU 缓存
题目链接：https://leetcode.cn/problems/lru-cache/  
类型：设计题  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc208'></a>
### LC 208：实现 Trie (前缀树)
题目链接：https://leetcode.cn/problems/implement-trie-prefix-tree/  
类型：设计题  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc200'></a>
### LC 200：岛屿数量
题目链接：https://leetcode.cn/problems/number-of-islands/  
类型：图/拓扑/并查集  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc207'></a>
### LC 207：课程表
题目链接：https://leetcode.cn/problems/course-schedule/  
类型：图/拓扑/并查集  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc2'></a>
### LC 2：两数相加
题目链接：https://leetcode.cn/problems/add-two-numbers/  
类型：链表  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc4'></a>
### LC 4：寻找两个正序数组的中位数
题目链接：https://leetcode.cn/problems/median-of-two-sorted-arrays/  
类型：二分/分治/搜索  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc10'></a>
### LC 10：正则表达式匹配
题目链接：https://leetcode.cn/problems/regular-expression-matching/  
类型：动态规划  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc23'></a>
### LC 23：合并 K 个升序链表
题目链接：https://leetcode.cn/problems/merge-k-sorted-lists/  
类型：堆/优先队列  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc31'></a>
### LC 31：下一个排列
题目链接：https://leetcode.cn/problems/next-permutation/  
类型：双指针/数组技巧  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc32'></a>
### LC 32：最长有效括号
题目链接：https://leetcode.cn/problems/longest-valid-parentheses/  
类型：栈/单调结构  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc48'></a>
### LC 48：旋转图像
题目链接：https://leetcode.cn/problems/rotate-image/  
类型：矩阵/模拟  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc55'></a>
### LC 55：跳跃游戏
题目链接：https://leetcode.cn/problems/jump-game/  
类型：贪心/区间/排序  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc62'></a>
### LC 62：不同路径
题目链接：https://leetcode.cn/problems/unique-paths/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc64'></a>
### LC 64：最小路径和
题目链接：https://leetcode.cn/problems/minimum-path-sum/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc72'></a>
### LC 72：编辑距离
题目链接：https://leetcode.cn/problems/edit-distance/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc84'></a>
### LC 84：柱状图中最大的矩形
题目链接：https://leetcode.cn/problems/largest-rectangle-in-histogram/  
类型：栈/单调结构  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc85'></a>
### LC 85：最大矩形
题目链接：https://leetcode.cn/problems/maximal-rectangle/  
类型：栈/单调结构  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc94'></a>
### LC 94：二叉树的中序遍历
题目链接：https://leetcode.cn/problems/binary-tree-inorder-traversal/  
类型：树  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc96'></a>
### LC 96：不同的二叉搜索树
题目链接：https://leetcode.cn/problems/unique-binary-search-trees/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc98'></a>
### LC 98：验证二叉搜索树
题目链接：https://leetcode.cn/problems/validate-binary-search-tree/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc114'></a>
### LC 114：二叉树展开为链表
题目链接：https://leetcode.cn/problems/flatten-binary-tree-to-linked-list/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc124'></a>
### LC 124：二叉树中的最大路径和
题目链接：https://leetcode.cn/problems/binary-tree-maximum-path-sum/  
类型：树  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc136'></a>
### LC 136：只出现一次的数字
题目链接：https://leetcode.cn/problems/single-number/  
类型：位运算  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc142'></a>
### LC 142：环形链表 II
题目链接：https://leetcode.cn/problems/linked-list-cycle-ii/  
类型：链表  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc148'></a>
### LC 148：排序链表
题目链接：https://leetcode.cn/problems/sort-list/  
类型：链表  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc152'></a>
### LC 152：乘积最大子数组
题目链接：https://leetcode.cn/problems/maximum-product-subarray/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc155'></a>
### LC 155：最小栈
题目链接：https://leetcode.cn/problems/min-stack/  
类型：设计题  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc160'></a>
### LC 160：相交链表
题目链接：https://leetcode.cn/problems/intersection-of-two-linked-lists/  
类型：链表  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc169'></a>
### LC 169：多数元素
题目链接：https://leetcode.cn/problems/majority-element/  
类型：哈希/前缀和/计数  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc221'></a>
### LC 221：最大正方形
题目链接：https://leetcode.cn/problems/maximal-square/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc234'></a>
### LC 234：回文链表
题目链接：https://leetcode.cn/problems/palindrome-linked-list/  
类型：链表  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc279'></a>
### LC 279：完全平方数
题目链接：https://leetcode.cn/problems/perfect-squares/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc297'></a>
### LC 297：二叉树的序列化与反序列化
题目链接：https://leetcode.cn/problems/serialize-and-deserialize-binary-tree/  
类型：树  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc301'></a>
### LC 301：删除无效的括号
题目链接：https://leetcode.cn/problems/remove-invalid-parentheses/  
类型：回溯/搜索  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc312'></a>
### LC 312：戳气球
题目链接：https://leetcode.cn/problems/burst-balloons/  
类型：动态规划  
难度：Hard  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc338'></a>
### LC 338：比特位计数
题目链接：https://leetcode.cn/problems/counting-bits/  
类型：位运算  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc399'></a>
### LC 399：除法求值
题目链接：https://leetcode.cn/problems/evaluate-division/  
类型：图/拓扑/并查集  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc406'></a>
### LC 406：根据身高重建队列
题目链接：https://leetcode.cn/problems/queue-reconstruction-by-height/  
类型：贪心/区间/排序  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc416'></a>
### LC 416：分割等和子集
题目链接：https://leetcode.cn/problems/partition-equal-subset-sum/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc437'></a>
### LC 437：路径总和 III
题目链接：https://leetcode.cn/problems/path-sum-iii/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc448'></a>
### LC 448：找到所有数组中消失的数字
题目链接：https://leetcode.cn/problems/find-all-numbers-disappeared-in-an-array/  
类型：哈希/前缀和/计数  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc461'></a>
### LC 461：汉明距离
题目链接：https://leetcode.cn/problems/hamming-distance/  
类型：位运算  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc494'></a>
### LC 494：目标和
题目链接：https://leetcode.cn/problems/target-sum/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc538'></a>
### LC 538：把二叉搜索树转换为累加树
题目链接：https://leetcode.cn/problems/convert-bst-to-greater-tree/  
类型：树  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc581'></a>
### LC 581：最短无序连续子数组
题目链接：https://leetcode.cn/problems/shortest-unsorted-continuous-subarray/  
类型：栈/单调结构  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc617'></a>
### LC 617：合并二叉树
题目链接：https://leetcode.cn/problems/merge-two-binary-trees/  
类型：树  
难度：Easy  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc621'></a>
### LC 621：任务调度器
题目链接：https://leetcode.cn/problems/task-scheduler/  
类型：贪心/区间/排序  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```

<a id='lc647'></a>
### LC 647：回文子串
题目链接：https://leetcode.cn/problems/palindromic-substrings/  
类型：动态规划  
难度：Medium  
状态：TODO  
要点：
复杂度：

```java
// TODO
```
