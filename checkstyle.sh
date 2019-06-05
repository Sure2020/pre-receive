#!/bin/sh
 
#checkstyle的jar包路径
CHECKSTYLE_JAR='/mnt/checkstyle-8.20-all.jar'
#checkstyle的配置文件路径
CHECKSTYLE_XML='/mnt/alibaba_checks_full.xml'
#需要执行Java编码规范检查的微服务仓库列表文件
REPOSITORY_LIST='/mnt/repository_list.txt'

REPOSITORY_PATH=`pwd`
REPOSITORY_NAME=`echo ${REPOSITORY_PATH##*/} | awk -F . '{print $1}'`
echo "当前仓库名： $REPOSITORY_NAME"
REPOSITORY_EXIST=`cat $REPOSITORY_LIST | grep -Fx $REPOSITORY_NAME`

#判断正在提交代码的仓库是否在检查列表中，不在则直接退出
if [ -z "$REPOSITORY_EXIST"  ]; then
    exit 0
else
    echo "该仓库在Java编码规范检查列表内，即将执行检查"
fi

#Java编码检查逻辑
reject=0
 
while read oldrev newrev refname; do
 
    #为了规避当初次提交，因oldrev为全0而报错的问题
    if [ "$oldrev" == "0000000000000000000000000000000000000000" ];then
        oldrev="${newrev}"
    fi
    #获取被修改的java文件 
    files=`git diff --name-only ${oldrev} ${newrev}  | grep -e "\.java$"`
    
    if [ -n "$files" ]; then
        tempDir=`mktemp -d`
        #echo "tempDir: $tempDir"
        #将文件复制到一个临时文件夹中
        for file in ${files}; do
            mkdir -p "${tempDir}/`dirname ${file}`" &>/dev/null
            git show $newrev:$file > ${tempDir}/${file} 
        done;
    
        filesToCheck=`find $tempDir -name '*.java'`
        echo "将检查的文件: $filesToCheck"
        #执行Java编码规范检查
        checkResult=`java -jar $CHECKSTYLE_JAR -c $CHECKSTYLE_XML $filesToCheck`
        checkExitCode=$?
        echo "检查结果: $checkResult"

        #如果检查命令执行失败，则报错并退出
        #if [ ${checkExitCode} -ne 0 ] ; then
        #    echo "检查命令执行失败"
        #    reject=${checkExitCode}
        #fi

        #如果代码中有不规范项，则报错并拒绝提交
        #if [ -n "$checkResult" ]; then
        if [ ${checkExitCode} -ne 0 ] ; then
            echo "未通过Java编码规范检查，请修改后重试"
            reject=1
        fi

        #最后将临时文件夹删除
        rm -rf $tempDir
    fi    
done
 
exit $reject
