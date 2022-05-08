---
title: LeetCode Hot 100
date: 2020-08-03 22:35:04
tags: 算法
top: 9
---

LeetCode 1：两数之和

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



LeetCode 2：两数相加

