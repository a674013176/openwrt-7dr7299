#!/bin/bash
set -e
echo "===== DIY脚本：注入mtd-rw + 移除DTS只读 ====="

# 生成kmod-mtd-rw模块
mkdir -p package/mtd-rw/src

cat > package/mtd-rw/Makefile <<'EOF'
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=mtd-rw
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_MAINTAINER:=CI Build
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/mtd-rw
  SUBMENU:=Other modules
  TITLE:=Unlock read-only MTD partitions
  FILES:=$(PKG_BUILD_DIR)/mtd-rw.ko
  AUTOLOAD:=$(call AutoLoad,95,mtd-rw)
endef

define Build/Compile
	$(KERNEL_MAKE) M=$(PKG_BUILD_DIR) modules
endef
$(eval $(call KernelPackage,mtd-rw))
EOF

cat > package/mtd-rw/src/mtd-rw.c <<'EOF'
#include <linux/module.h>
#include <linux/mtd/mtd.h>

static int i_want_a_brick;
module_param(i_want_a_brick, int, 0644);
MODULE_PARM_DESC(i_want_a_brick, "Set i_want_a_brick=1 to unlock");

static int __init mtd_rw_init(void)
{
	struct mtd_info *mtd;
	if (!i_want_a_brick) {
		pr_err("mtd-rw: refuse load, add i_want_a_brick=1\n");
		return -EPERM;
	}
	mtd_for_each_device(mtd) {
		mtd->flags |= MTD_WRITEABLE;
		pr_info("mtd-rw unlock mtd%d: %s\n", mtd->index, mtd->name);
	}
	return 0;
}
static void __exit mtd_rw_exit(void){}
module_init(mtd_rw_init);
module_exit(mtd_rw_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Force unlock all RO MTD");
EOF

# 打印所有TP-Link设备树，核对真实文件名
ls -lh target/linux/mediatek/dts/*tplink*

# ⚠️首次编译根据日志输出修改下面文件名！
DTS_FILE="target/linux/mediatek/dts/mt7988a-tplink-7dr7299.dts"
if [ -f "${DTS_FILE}" ]; then
    sed -i '/read-only;/d' "${DTS_FILE}"
    echo "✅ 已移除DTS read-only; : ${DTS_FILE}"
else
    echo "❌ DTS文件不存在！查看上方ls输出，修改脚本内DTS_FILE路径"
fi

echo "===== DIY脚本执行完成 ====="
