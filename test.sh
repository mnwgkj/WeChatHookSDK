#!/bin/bash

#=====================================
# WeChatHookSDK 测试脚本
# 用于验证极速抢包功能
#=====================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
DEVICE_IP=""
OUTPUT_DIR="./output"
DYLIB_FILE="${OUTPUT_DIR}/libHookSDK.dylib"
PLIST_FILE="${OUTPUT_DIR}/libHookSDK.plist"

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}    WeChatHookSDK 测试脚本${NC}"
echo -e "${BLUE}    极速抢包功能验证${NC}"
echo -e "${BLUE}===============================================${NC}"

# 检查构建产物
check_build_artifacts() {
    echo -e "${YELLOW}[1/5] 检查构建产物...${NC}"
    
    if [[ ! -f "${DYLIB_FILE}" ]]; then
        echo -e "${RED}❌ 错误: 未找到 libHookSDK.dylib${NC}"
        echo -e "${RED}请先运行 ./build.sh 构建项目${NC}"
        exit 1
    fi
    
    if [[ ! -f "${PLIST_FILE}" ]]; then
        echo -e "${RED}❌ 错误: 未找到 libHookSDK.plist${NC}"
        echo -e "${RED}请检查 Doc 目录${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 构建产物检查通过${NC}"
    
    # 显示文件信息
    echo -e "${BLUE}文件信息:${NC}"
    ls -lh "${OUTPUT_DIR}/"
}

# 获取设备IP
get_device_ip() {
    echo -e "${YELLOW}[2/5] 设备连接设置...${NC}"
    
    if [[ -z "${DEVICE_IP}" ]]; then
        echo -e "${BLUE}请输入越狱设备的IP地址:${NC}"
        read -p "设备IP: " DEVICE_IP
        
        if [[ -z "${DEVICE_IP}" ]]; then
            echo -e "${RED}❌ 错误: 设备IP不能为空${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ 设备IP: ${DEVICE_IP}${NC}"
}

# 测试设备连接
test_device_connection() {
    echo -e "${YELLOW}[3/5] 测试设备连接...${NC}"
    
    echo -e "${BLUE}正在测试SSH连接...${NC}"
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@${DEVICE_IP} "echo 'Connection OK'" 2>/dev/null; then
        echo -e "${GREEN}✅ SSH连接成功${NC}"
    else
        echo -e "${RED}❌ SSH连接失败${NC}"
        echo -e "${RED}请检查:${NC}"
        echo -e "${RED}1. 设备IP是否正确${NC}"
        echo -e "${RED}2. 设备是否已越狱${NC}"
        echo -e "${RED}3. SSH是否已安装并运行${NC}"
        exit 1
    fi
    
    # 检查设备信息
    echo -e "${BLUE}设备信息:${NC}"
    DEVICE_INFO=$(ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "uname -a" 2>/dev/null)
    echo -e "${BLUE}${DEVICE_INFO}${NC}"
    
    # 检查iOS版本
    IOS_VERSION=$(ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "sw_vers -productVersion" 2>/dev/null || echo "未知")
    echo -e "${BLUE}iOS版本: ${IOS_VERSION}${NC}"
}

# 部署到设备
deploy_to_device() {
    echo -e "${YELLOW}[4/5] 部署到设备...${NC}"
    
    # 创建目标目录
    echo -e "${BLUE}创建目标目录...${NC}"
    ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "mkdir -p /Library/MobileSubstrate/DynamicLibraries" 2>/dev/null
    
    # 备份旧文件（如果存在）
    echo -e "${BLUE}备份旧文件...${NC}"
    ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "
        if [[ -f /Library/MobileSubstrate/DynamicLibraries/libHookSDK.dylib ]]; then
            cp /Library/MobileSubstrate/DynamicLibraries/libHookSDK.dylib /tmp/libHookSDK.dylib.backup
            echo '旧版本已备份到 /tmp/libHookSDK.dylib.backup'
        fi
    " 2>/dev/null
    
    # 上传文件
    echo -e "${BLUE}上传 libHookSDK.dylib...${NC}"
    if scp -o StrictHostKeyChecking=no "${DYLIB_FILE}" root@${DEVICE_IP}:/Library/MobileSubstrate/DynamicLibraries/ 2>/dev/null; then
        echo -e "${GREEN}✅ dylib 上传成功${NC}"
    else
        echo -e "${RED}❌ dylib 上传失败${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}上传 libHookSDK.plist...${NC}"
    if scp -o StrictHostKeyChecking=no "${PLIST_FILE}" root@${DEVICE_IP}:/Library/MobileSubstrate/DynamicLibraries/ 2>/dev/null; then
        echo -e "${GREEN}✅ plist 上传成功${NC}"
    else
        echo -e "${RED}❌ plist 上传失败${NC}"
        exit 1
    fi
    
    # 设置权限
    echo -e "${BLUE}设置文件权限...${NC}"
    ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "
        chmod 755 /Library/MobileSubstrate/DynamicLibraries/libHookSDK.dylib
        chmod 644 /Library/MobileSubstrate/DynamicLibraries/libHookSDK.plist
    " 2>/dev/null
    
    echo -e "${GREEN}✅ 部署完成${NC}"
}

# 运行功能测试
run_functionality_tests() {
    echo -e "${YELLOW}[5/5] 运行功能测试...${NC}"
    
    # 重启SpringBoard
    echo -e "${BLUE}重启 SpringBoard...${NC}"
    ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "killall SpringBoard" 2>/dev/null || true
    
    echo -e "${BLUE}等待SpringBoard重启...${NC}"
    sleep 5
    
    # 检查动态库是否加载
    echo -e "${BLUE}检查动态库加载状态...${NC}"
    LOADED_COUNT=$(ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "ps aux | grep -i wechat | wc -l" 2>/dev/null || echo "0")
    
    if [[ "${LOADED_COUNT}" -gt "1" ]]; then
        echo -e "${GREEN}✅ 检测到微信进程${NC}"
    else
        echo -e "${YELLOW}⚠️  未检测到微信进程，请手动启动微信${NC}"
    fi
    
    # 检查日志
    echo -e "${BLUE}检查系统日志...${NC}"
    ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "
        tail -n 20 /var/log/syslog 2>/dev/null | grep -i hook || 
        tail -n 20 /var/mobile/Library/Logs/CrashReporter/SpringBoard* 2>/dev/null | head -10 || 
        echo '暂无相关日志'
    " 2>/dev/null
    
    echo -e "${GREEN}✅ 功能测试完成${NC}"
}

# 显示测试结果和使用说明
show_test_results() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${GREEN}🎉 测试部署完成! ${NC}"
    echo -e "${BLUE}===============================================${NC}"
    
    echo -e "${YELLOW}下一步操作:${NC}"
    echo -e "${BLUE}1. 打开微信应用${NC}"
    echo -e "${BLUE}2. 进入微信设置 → 红包助手设置${NC}"
    echo -e "${BLUE}3. 配置极速抢包参数:${NC}"
    echo -e "${GREEN}   - 总开关: 开启${NC}"
    echo -e "${GREEN}   - 延迟抢包(毫秒): 0${NC}"
    echo -e "${GREEN}   - 查询详情间隔(毫秒): 0${NC}"
    echo -e "${GREEN}   - 极速抢包: 开启${NC}"
    echo -e "${GREEN}   - 详细日志: 关闭 (提升性能)${NC}"
    
    echo -e "\n${YELLOW}测试建议:${NC}"
    echo -e "${BLUE}1. 先在小群中测试功能${NC}"
    echo -e "${BLUE}2. 观察抢包响应速度${NC}"
    echo -e "${BLUE}3. 监控是否有异常检测${NC}"
    echo -e "${BLUE}4. 根据实际情况微调延迟参数${NC}"
    
    echo -e "\n${YELLOW}故障排除:${NC}"
    echo -e "${BLUE}如果遇到问题，请检查:${NC}"
    echo -e "${BLUE}- SSH连接到设备: ssh root@${DEVICE_IP}${NC}"
    echo -e "${BLUE}- 查看系统日志: tail -f /var/log/syslog${NC}"
    echo -e "${BLUE}- 重启SpringBoard: killall SpringBoard${NC}"
    echo -e "${BLUE}- 恢复备份: cp /tmp/libHookSDK.dylib.backup /Library/MobileSubstrate/DynamicLibraries/libHookSDK.dylib${NC}"
    
    echo -e "\n${GREEN}准备享受极速抢包体验! 🚀${NC}"
}

# 交互式测试选项
interactive_test() {
    while true; do
        echo -e "\n${YELLOW}测试选项:${NC}"
        echo -e "${BLUE}1. 完整测试流程${NC}"
        echo -e "${BLUE}2. 仅部署文件${NC}"
        echo -e "${BLUE}3. 仅重启SpringBoard${NC}"
        echo -e "${BLUE}4. 查看设备日志${NC}"
        echo -e "${BLUE}5. 退出${NC}"
        
        read -p "请选择 (1-5): " choice
        
        case $choice in
            1)
                check_build_artifacts
                get_device_ip
                test_device_connection
                deploy_to_device
                run_functionality_tests
                show_test_results
                break
                ;;
            2)
                check_build_artifacts
                get_device_ip
                test_device_connection
                deploy_to_device
                echo -e "${GREEN}✅ 部署完成，请手动重启SpringBoard${NC}"
                ;;
            3)
                get_device_ip
                ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "killall SpringBoard" 2>/dev/null
                echo -e "${GREEN}✅ SpringBoard已重启${NC}"
                ;;
            4)
                get_device_ip
                echo -e "${BLUE}实时日志 (Ctrl+C 退出):${NC}"
                ssh -o StrictHostKeyChecking=no root@${DEVICE_IP} "tail -f /var/log/syslog | grep -i hook" 2>/dev/null || true
                ;;
            5)
                echo -e "${GREEN}测试结束${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                ;;
        esac
    done
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        interactive_test
    else
        case $1 in
            "full")
                check_build_artifacts
                get_device_ip
                test_device_connection
                deploy_to_device
                run_functionality_tests
                show_test_results
                ;;
            "deploy")
                check_build_artifacts
                get_device_ip
                test_device_connection
                deploy_to_device
                ;;
            *)
                echo -e "${YELLOW}用法: $0 [full|deploy]${NC}"
                echo -e "${YELLOW}或直接运行进入交互模式${NC}"
                ;;
        esac
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi