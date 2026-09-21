#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PROJECT_NAME="$(basename "$ROOT_DIR")"
BRANCH_NAME="$(git branch --show-current)"
if [ -z "$BRANCH_NAME" ]; then
    echo "无法确定当前分支，不能生成发布 Tag。" >&2
    exit 1
fi
if [ "$BRANCH_NAME" != "master" ]; then
    echo "当前分支为 $BRANCH_NAME，生产 Tag 只能从 master 创建。" >&2
    exit 1
fi

DATE_STRING="$(date '+%Y-%m-%d/%H-%M-%S')"
TAG_NAME="${BRANCH_NAME}/${PROJECT_NAME}/${DATE_STRING}"

echo "生成的标签名: $TAG_NAME"
echo "Git 仓库地址: $(git remote get-url origin)"
git tag "$TAG_NAME"

read -r -p "是否要推送标签到远程仓库？(y/n): " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    git push origin "$TAG_NAME"
    echo "标签已成功推送到远程仓库。"
else
    git tag -d "$TAG_NAME" >/dev/null
    echo "标签未推送到远程仓库，已删除本地标签。"
fi
