---
title: Android-流量统计
typora-root-url: ../
date: 2020-09-15 19:19:43
tags: Android
top: 9
---

## 流量统计

Android目前提供了两种流量计算方案

- `TrafficStats`
- `NetworkStatsManager`

这两种方案有着各自的优缺点与限制，下面简单的记录一下

![流量统计](/images/流量统计.png)

### TrafficStats

> Android API8后提供的该类，可以获取**设备重启以来的流量信息**。

```java
public class TrafficStats {
  public static long getMobileRxBytes() //移动网络接受的总流量
  public static long getMobileTxBytes() //移动网络发送的总流量
  public static long getTotalTxBytes() //发送的总数据流量
  public static long getTotalRxBytes() //接收的总数据流量
  public static long getUidRxBytes(int uid) //指定uid接收的流量
  public static long getUidTxBytes(int uid) //指定uid发送的流量
}
```

以上为`TrafficStats`提供的基本方法

根据上述方法可以大致得到当前设备使用的流量数据，`getMobileXX()`获取移动网络数据，`getTotalXX()`获取总流量数据，所以`getTotalXX()-getMobileXX()`大致可以得到Wifi的使用数据。还可以通过指定`getUidXX()`获取指定应用的流量数据。

补充：这个差值是“近似值”而非严格Wi-Fi口径。

- `Total`口径可能包含除蜂窝外的其他网络接口（如以太网/VPN等）。
- 不同厂商ROM对接口归类存在差异，跨机型对比时建议统一口径。

优点：

- 调用方法简单，无需特别权限

缺点：

- 无法获取某个时间段内的流量消耗

  统计的是设备启动以来的流量数据，无法判断是从哪个时间段开始的流量统计

- 无法获取指定应用的wifi类型流量数据

  虽然可以通过监听网络变化去获取对应数据，实际可操作性不高

#### 简单原理介绍

上述方法内部实现都是通过`getStatsService()`进行调用

```java
    private synchronized static INetworkStatsService getStatsService() {
        if (sStatsService == null) {
            sStatsService = INetworkStatsService.Stub.asInterface(
                    ServiceManager.getService(Context.NETWORK_STATS_SERVICE));
        }
        return sStatsService;
    }

    public static long getTotalTxPackets() {
        try {
            return getStatsService().getTotalStats(TYPE_TX_PACKETS);
        } catch (RemoteException e) {
            throw e.rethrowFromSystemServer();
        }
    }
```

通过AIDL调用到`NetworkStatsService`

```java
public class NetworkStatsService extends INetworkStatsService.Stub {
 ...
@Override
    public long getTotalStats(int type) {
        long nativeTotalStats = nativeGetTotalStat(type, checkBpfStatsEnable());
        if (nativeTotalStats == -1) {
            return nativeTotalStats;
        } else {
            // Refer to comment in getIfaceStats
            return nativeTotalStats + getTetherStats(IFACE_ALL, type);
        }
    }
}
   //判断是否启用 bpf流量监控
   mUseBpfTrafficStats = new File("/sys/fs/bpf/traffic_uid_stats_map").exists();

    private boolean checkBpfStatsEnable() {
        return mUseBpfTrafficStats;
    }
```

`bpf流量监控`是在Android 9之后提供的，需要在Android P上的设备才可以使用。老的监控方式逐渐被废弃。

通过JNI调用`com_android_server_net_NetworkStatsService.cpp`

```c++
//流量记录文件路径
static const char* QTAGUID_IFACE_STATS = "/proc/net/xt_qtaguid/iface_stat_fmt";
static const char* QTAGUID_UID_STATS = "/proc/net/xt_qtaguid/stats";

static jlong getTotalStat(JNIEnv* env, jclass clazz, jint type, jboolean useBpfStats) {
    Stats stats = {};

    if (useBpfStats) {
        if (bpfGetIfaceStats(NULL, &stats) == 0) {
            return getStatsType(&stats, (StatsType) type);
        } else {
            return UNKNOWN;
        }
    }

    if (parseIfaceStats(NULL, &stats) == 0) {
        return getStatsType(&stats, (StatsType) type);
    } else {
        return UNKNOWN;
    }
}
```

在Android 9之前，通过读取`/proc/net/xt_qtaguid/stats`文件内容进行解析获取对应流量数据。

Android9 之后，通过读取`/sys/fs/bpf/traffic_uid_stats_map`获取数据

补充：流量计数本质是内核累计值。

- 设备重启后计数会重新累计，不适合直接当“日/月账单”使用。
- 需要时间段统计时，应保存前后两次快照做差，或改用`NetworkStatsManager`按时间窗口查询。

#### 使用实例

```java
public class TrafficStatsHelper {


    public static long getAllRxBytes() {
        return TrafficStats.getTotalRxBytes();
    }

    public static long getAllTxBytes() {
        return TrafficStats.getTotalTxBytes();
    }

    public static long getAllRxBytesMobile() {
        return TrafficStats.getMobileRxBytes();
    }

    public static long getAllTxBytesMobile() {
        return TrafficStats.getMobileTxBytes();
    }

    public static long getAllRxBytesWifi() {
        return TrafficStats.getTotalRxBytes() - TrafficStats.getMobileRxBytes();
    }

    public static long getAllTxBytesWifi() {
        return TrafficStats.getTotalTxBytes() - TrafficStats.getMobileTxBytes();
    }

    public static long getPackageRxBytes(int uid) {
        return TrafficStats.getUidRxBytes(uid);
    }

    public static long getPackageTxBytes(int uid) {
        return TrafficStats.getUidTxBytes(uid);
    }
}

调用实例：
TrafficStats.getUidRxBytes(Process.myUid()) //当前不支持外部获取对应应用的流量信息，如果有需求需要使用NetworkStatsManager
```









### NetworkStatsManager

> Android 6.0之后新增加的类，可以获取历史的流量信息，并且支持查询时间段的流量数据

```java
public Bucket querySummaryForDevice(int networkType, String subscriberId,
            long startTime, long endTime)  //获取当前设备指定网络类型以及时间间隔内的所有流量信息

public NetworkStats queryDetailsForUid(int networkType, String subscriberId,
            long startTime, long endTime, int uid) //获取某id下的所有流量信息
  
public static class Bucket {
 ...
        public long getRxBytes() { //接收的流量
            return mRxBytes;
        }

        public long getTxBytes() { //发送的流量
            return mTxBytes;
        }
}
```

补充：时间参数是毫秒时间戳（epoch millis），建议统一使用同一时区/时钟来源。

- 查询结果按系统采样窗口聚合，不保证“实时逐秒”精度。
- 做实时面板时建议结合轮询间隔与缓存策略，避免频繁重查。

以上为`NetworkStatsManager`的主要调用方法

根据上述提供的方法，可以得到设备历史流量数据，并且支持按照`networkType`区分和`startTime~endTime`获取指定时间段的流量数据。

优点：

- 可以获取指定类型以及时间段的流量数据

缺点：

- 需要申请特殊权限以及做权限适配
- 使用较复杂

#### 简单原理介绍

INetworkStatsSession.aidl -> getDeviceSummaryForNetwork

NetworkStatsService.java

NetworkStatsCollection.java -> getHistory()

#### 使用实例

```java
AndroidManifest.xml 配置权限
  
    <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
    <uses-permission
        android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions"/>
          
申请权限
    private void requestPermissions() {
        //检测有无 查看应用使用情况权限
        if (!hasPermissionToReadNetworkHistory()) {
            return;
        }
        //检测有无获取 READ_PHONE_STATE 权限
        if (!hasPermissionToReadPhoneStats()) {
            //申请对应权限
            requestPhoneStateStats();
        }
    }

 private boolean hasPermissionToReadNetworkHistory() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true;
        }
        final AppOpsManager appOps = (AppOpsManager) getSystemService(Context.APP_OPS_SERVICE);
        int mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(), getPackageName());
        if (mode == AppOpsManager.MODE_ALLOWED) {
            return true;
        }
        appOps.startWatchingMode(AppOpsManager.OPSTR_GET_USAGE_STATS,
                getApplicationContext().getPackageName(),
                new AppOpsManager.OnOpChangedListener() {
                    @Override
                    @TargetApi(Build.VERSION_CODES.M)
                    public void onOpChanged(String op, String packageName) {
                        int mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                                android.os.Process.myUid(), getPackageName());
                        if (mode != AppOpsManager.MODE_ALLOWED) {
                            return;
                        }
                        appOps.stopWatchingMode(this);
                        Intent intent = new Intent(StatsActivity.this, StatsActivity.class);
                        if (getIntent().getExtras() != null) {
                            intent.putExtras(getIntent().getExtras());
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_NEW_TASK);
                        getApplicationContext().startActivity(intent);
                    }
                });
        requestReadNetworkHistoryAccess();
        return false;
    }

    private void requestReadNetworkHistoryAccess() {
        Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
        startActivity(intent);
    }

//上述权限申请完毕后，调用对应方法获取流量数据
     public long getPackageBytesWithNetTypeAndFlow(Context context, boolean isRx/*Rx、Tx*/,
                                                   int networkType/*TYPE_MOBILE，TYPE_WIFI*/) {
        NetworkStats networkStats = null;
        try {
            networkStats = networkStatsManager.queryDetailsForUid(networkType, getSubscriberId(context, networkType),
                    0, System.currentTimeMillis(), packageUid);
            long bytes = 0L;
            NetworkStats.Bucket bucket = new NetworkStats.Bucket();
            while (networkStats.hasNextBucket()) {
                networkStats.getNextBucket(bucket);
                bytes += isRx ? bucket.getRxBytes() : bucket.getTxBytes();
            }
            return bytes;
        } catch (RemoteException e) {
            return -1;
        } finally {
            if (networkStats != null) {
                networkStats.close();
            }
        }
    }

    private String getSubscriberId(Context context, int networkType) {
        if (ConnectivityManager.TYPE_MOBILE == networkType) {
            TelephonyManager tm = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            return tm.getSubscriberId();
        }
        return null;
    }
```

补充：高版本对`subscriberId`读取限制更严格，移动网络查询需做好降级处理（拿不到时避免崩溃/空指针）。



## 方案选择补充

- 只看“设备启动以来累计流量”且无需复杂权限：优先`TrafficStats`。
- 需要“按时间段/按UID”统计：使用`NetworkStatsManager`。
- 多机型/多ROM做一致性对比时，先统一统计口径（网络类型、时间窗口、是否包含其他接口）。



## 参考链接

[TrafficStats流程分析](https://www.jianshu.com/p/061f8889a888)

[eBPF流量监控](https://source.android.google.cn/devices/tech/datausage/ebpf-traffic-monitor)

[NetStats Demo](https://github.com/RobertZagorski/NetworkStats.git)
