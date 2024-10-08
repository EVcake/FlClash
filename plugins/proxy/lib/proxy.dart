import 'dart:io';

import 'proxy_platform_interface.dart';
import "package:path/path.dart";

enum ProxyTypes { http, https, socks }

class Proxy extends ProxyPlatform {
  static String url = "127.0.0.1";

  @override
  Future<bool?> startProxy(int port) async {
    return switch (Platform.operatingSystem) {
      "macos" => await _startProxyWithMacos(port),
      "linux" => await _startProxyWithLinux(port),
      "windows" => await ProxyPlatform.instance.startProxy(port),
      String() => false,
    };
  }

  @override
  Future<bool?> stopProxy() async {
    return switch (Platform.operatingSystem) {
      "macos" => await _stopProxyWithMacos(),
      "linux" => await _stopProxyWithLinux(),
      "windows" => await ProxyPlatform.instance.stopProxy(),
      String() => false,
    };
  }

  Future<bool> _startProxyWithLinux(int port) async {
    try {
      final homeDir = Platform.environment['HOME']!;
      final configDir = join(homeDir, ".config");
      final cmdList = List<List<String>>.empty(growable: true);
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
      final isKDE = desktop == "KDE";
      for (final type in ProxyTypes.values) {
        cmdList.add(
          ["gsettings", "set", "org.gnome.system.proxy", "mode", "manual"],
        );
        cmdList.add(
          [
            "gsettings",
            "set",
            "org.gnome.system.proxy.${type.name}",
            "host",
            url
          ],
        );
        cmdList.add(
          [
            "gsettings",
            "set",
            "org.gnome.system.proxy.${type.name}",
            "port",
            "$port"
          ],
        );
        if (isKDE) {
          cmdList.add(
            [
              "kwriteconfig5",
              "--file",
              "$configDir/kioslaverc",
              "--group",
              "Proxy Settings",
              "--key",
              "ProxyType",
              "1"
            ],
          );
          cmdList.add(
            [
              "kwriteconfig5",
              "--file",
              "$configDir/kioslaverc",
              "--group",
              "Proxy Settings",
              "--key",
              "${type.name}Proxy",
              "${type.name}://$url:$port"
            ],
          );
        }
      }
      for (final cmd in cmdList) {
        await Process.run(cmd[0], cmd.sublist(1), runInShell: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _stopProxyWithLinux() async {
    try {
      final homeDir = Platform.environment['HOME']!;
      final configDir = join(homeDir, ".config/");
      final cmdList = List<List<String>>.empty(growable: true);
      final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
      final isKDE = desktop == "KDE";
      cmdList
          .add(["gsettings", "set", "org.gnome.system.proxy", "mode", "none"]);
      if (isKDE) {
        cmdList.add([
          "kwriteconfig5",
          "--file",
          "$configDir/kioslaverc",
          "--group",
          "Proxy Settings",
          "--key",
          "ProxyType",
          "0"
        ]);
      }
      for (final cmd in cmdList) {
        await Process.run(cmd[0], cmd.sublist(1));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _startProxyWithMacos(int port) async {
    try {
      final devices = await _getNetworkDeviceListWithMacos();
      for (final dev in devices) {
        await Future.wait([
          Process.run(
              "/usr/sbin/networksetup", ["-setwebproxystate", dev, "on"]),
          Process.run(
              "/usr/sbin/networksetup", ["-setwebproxy", dev, url, "$port"]),
          Process.run(
              "/usr/sbin/networksetup", ["-setsecurewebproxystate", dev, "on"]),
          Process.run("/usr/sbin/networksetup",
              ["-setsecurewebproxy", dev, url, "$port"]),
          Process.run("/usr/sbin/networksetup",
              ["-setsocksfirewallproxystate", dev, "on"]),
          Process.run("/usr/sbin/networksetup",
              ["-setsocksfirewallproxy", dev, url, "$port"]),
        ]);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _stopProxyWithMacos() async {
    try {
      final devices = await _getNetworkDeviceListWithMacos();
      for (final dev in devices) {
        await Future.wait([
          Process.run(
              "/usr/sbin/networksetup", ["-setautoproxystate", dev, "off"]),
          Process.run(
              "/usr/sbin/networksetup", ["-setwebproxystate", dev, "off"]),
          Process.run("/usr/sbin/networksetup",
              ["-setsecurewebproxystate", dev, "off"]),
          Process.run("/usr/sbin/networksetup",
              ["-setsocksfirewallproxystate", dev, "off"]),
        ]);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _getNetworkDeviceListWithMacos() async {
    final res = await Process.run(
        "/usr/sbin/networksetup", ["-listallnetworkservices"]);
    final lines = res.stdout.toString().split("\n");
    lines.removeWhere((element) => element.contains("*"));
    return lines;
  }
}
