#!/bin/bash


if [[ $# != 1 ]]; then
	echo "./update.sh [app文件路径名]"
	exit
fi

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH

RLSAPP=${1%/}
KEYTEMP="key.txt"
PRIVKEY="key2.txt"

CURDIR="$PWD"
appFullName=`basename "$RLSAPP"`
appName="${appFullName%.*}"
appExt="${appFullName##*.}"

if [[ -d "$RLSAPP" ]]; then

	spctlRes=`spctl --verbose=4 --assess --type execute "$RLSAPP" 2>&1`
	spctlPass=`echo ${spctlRes} | grep ": accepted"`
	if [[ -n ${spctlPass} ]]; then
		echo "Passed spctl"
	else
		echo "spctl verification failed"
		exit 1
	fi

	infoFile="${RLSAPP}/Contents/Info.plist"
	# 得到版本信息
	shortVer=`/usr/libexec/PlistBuddy -c 'Print:CFBundleShortVersionString' "${infoFile}"`
	echo "ShortVersionString:      " $shortVer

	verNum=`/usr/libexec/PlistBuddy -c 'Print:CFBundleVersion' "${infoFile}"`
	echo "VersionNumber:           " $verNum

	# 获取 压缩文件文件名
	DEPLOYBIN="${CURDIR}/releases/${appName}-$shortVer-${verNum}.zip"

    # 如果之前有拷贝就先删除
	rm -Rf $DEPLOYBIN

	# 压缩APP文件
    cd "$RLSAPP/.."
    zip -ry "$DEPLOYBIN" "$appFullName" > /dev/null
    cd "${CURDIR}"

	# 获取压缩文件尺寸
	fileSize=`stat -f %z "$DEPLOYBIN"`
	echo "FileSize:                " $fileSize

	# 获取压缩文件修改时间
	binTime=`stat -f %Sm -t "%a, %d %b %Y %H:%M:%S" "$DEPLOYBIN"`" +0900"
	echo "BinTime:                 " $binTime
	releaseDate=`stat -f %Sm -t "%Y/%m/%d" "$DEPLOYBIN"`

	# 获取压缩文件 签名
	security find-generic-password -g -s "MPlayerX Private Key" 1>/dev/null 2>$KEYTEMP
	ruby scripts/parsePriKey.rb $KEYTEMP > $PRIVKEY
	rm -Rf $KEYTEMP

	signature=`openssl dgst -sha1 -binary $DEPLOYBIN | openssl dgst -dss1 -sign $PRIVKEY | openssl enc -base64`
	rm -Rf $PRIVKEY
	echo "Signature:               " $signature

	if [[ ${appExt} == "app" ]]; then

		echo "Update application"
		cat appcast-template.xml | sed -e "s|%ReleaseDate%|${releaseDate}|g" | sed -e "s|%VerStr%|${shortVer}|g" | sed -e "s|%VerNum%|${verNum}|g" | sed -e "s|%Time%|${binTime}|g" | sed -e "s|%FileSize%|${fileSize}|g" | sed -e "s|%Signature%|${signature}|g" > appcast.xml

	elif [[ ${appExt} == "bundle" ]]; then

		mpxMin=`/usr/libexec/PlistBuddy -c 'Print:MPXMinVersion' "${infoFile}"`
		echo "MPXMinVersion:           " $mpxMin

		echo "Update bundle"
		cat appcast-bundle-template.xml | sed -e "s|%ReleaseDate%|${releaseDate}|g" | sed -e "s|%VerStr%|${shortVer}|g" | sed -e "s|%VerNum%|${verNum}|g" | sed -e "s|%Time%|${binTime}|g" | sed -e "s|%FileSize%|${fileSize}|g" | sed -e "s|%Signature%|${signature}|g" | sed -e "s|%BundleName%|${appName}|g" | sed -e "s|%MPXMinVer%|${mpxMin}|g" > appcast-${appName}.xml
	fi
else
	echo "没有找到二进制文件，请确认。"
fi