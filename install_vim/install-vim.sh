sudo apt-get install vim
# 做个软链接（用vi命令代替vim）
sudo ln -sf /usr/bin/vim /usr/bin/vi

# 新建~/.vimrc并填写配置信息
cd ~
cat >>.vimrc<<EOF
syn on "语法支持
set laststatus=2 "始终显示状态栏
set tabstop=4 "一个制表符的长度
set softtabstop=4 "一个制表符的长度（可以大于tabstop）
set shiftwidth=4 "一个缩进的长度
set expandtab "使用空格替代制表符
set smarttab "智能制表符
set autoindent "自动缩进
set smartindent "只能缩进
set number "显示行号
set ruler "显示位置指示器
set backupdir=/tmp "设置备份文件目录
set directory=/tmp "设置临时文件目录
set ignorecase "检索时忽略大小写
set hls "检索时高亮显示匹配项
set helplang=cn "帮助系统设置为中文
"set foldmethod=syntax "代码折叠

set mouse=a

syntax enable
set background=dark
"colorscheme solarized      " 主题1
colorscheme tango-desert    " 主题2
EOF

# 创建目录~/.vim/colors/
mkdir .vim
cd .vim
mkdir colors
cd colors

# 下载两个主题文件tango-desert.vim和solarized.vim
wget --no-check-certificate https://raw.githubusercontent.com/sadjason/OpenStack/master/install_vim/tango-desert.vim -O tango-desert.vim
wget --no-check-certificate https://raw.githubusercontent.com/sadjason/OpenStack/master/install_vim/solarized.vim -O solarized.vim
