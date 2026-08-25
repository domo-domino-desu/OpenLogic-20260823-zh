# Open Logic Project
# Makefile

# YOU DO NOT HAVE TO USE THIS MAKEFILE
# Just run pdflatex on whichever tex file you want to compile
# The job of this makefile is to compile *everything*
 
# Requires latexmk https://www.ctan.org/pkg/latexmk/
# The PDF of the open-logic-config documentation also requires
# pandoc http://pandoc.org/

# 中译本正文含大量中文字符，pdflatex 无法渲染 CJK，必须用 lualatex 或
# xelatex；这里统一固定为 lualatex（-pdflatex=lualatex），不要求每次手动
# 传参数。

.PHONY : all everything courses branches clean clean-all FORCE_MAKE

TIKZ_CACHE := tikz-cache
# Four LuaLaTeX workers fit comfortably on the common 8-core/8-GiB setup;
# callers with more memory can override this (for example TIKZ_JOBS=8).
TIKZ_JOBS ?= 4
TIKZ_SOURCES := $(shell find assets/diagrams -name '*.tikz' -type f)
TIKZ_PDFS := $(patsubst assets/diagrams/%.tikz,$(TIKZ_CACHE)/%.pdf,$(TIKZ_SOURCES))
TIKZ_STAMP := $(TIKZ_CACHE)/.stamp

ALLTEXFILES = open-logic-debug.tex open-logic-complete.tex \
	$(shell grep 'INPUT content/.*/.*\.tex' open-logic-debug.fls | uniq | sed 's/INPUT //g' )

ALLPDFFILES = $(ALLTEXFILES:.tex=.pdf)

# 默认只构建发布版；需要调试版及其余产物时显式使用 `make everything`。
all: open-logic-complete.pdf

content/open-logic.pdf:

everything: $(ALLPDFFILES) open-logic-config.pdf index.html

courses: FORCE_MAKE
	for course in courses/* ; do \
		make -C $$course ;\
	done

branches: FORCE_MAKE
	git checkout master
	for branch in `git branch --list --no-column |grep -v master` ; do \
		git checkout $$branch ;\
		latexmk -pdf -pdflatex=lualatex -dvi- -ps- open-logic-debug ;\
		latexmk -pdf -pdflatex=lualatex -dvi- -ps- open-logic-complete ;\
		mkdir -p branches/$$branch ;\
		cp open-logic-debug.pdf open-logic-complete.pdf branches/$$branch ;\
	done
	git checkout master
	latexmk -pdf -pdflatex=lualatex -dvi- -ps- open-logic-debug
	latexmk -pdf -pdflatex=lualatex -dvi- -ps- open-logic-complete

open-logic-config.pdf: open-logic-config.sty
	grep -e "^%" -e "^$$" open-logic-config.sty | cut --bytes=3-|pandoc -f markdown -M date="`git log --format=format:"%ad %h" --date=short -1 open-logic-config.sty`" -o open-logic-config.pdf

open-logic-complete.pdf: $(TIKZ_STAMP)

%.pdf : %.tex FORCE_MAKE | $(TIKZ_CACHE)
	latexmk -pdf -pdflatex=lualatex -dvi- -ps- -cd $<

$(TIKZ_CACHE):
	mkdir -p $@

# These illustrations are self-contained TikZ paths.  Building them directly
# avoids having every external worker scan the full 1,000+ page master file.
$(TIKZ_CACHE)/%.pdf: assets/diagrams/%.tikz assets/diagrams/cache-wrapper.tex | $(TIKZ_CACHE)
	lualatex -interaction=batchmode -halt-on-error -jobname "$(@:.pdf=)" \
		'\def\olassetfile{$<}\input{assets/diagrams/cache-wrapper.tex}'

$(TIKZ_STAMP): $(TIKZ_SOURCES) assets/diagrams/cache-wrapper.tex | $(TIKZ_CACHE)
	$(MAKE) $(TIKZ_PDFS) -j$(TIKZ_JOBS)
	touch $@

clean:	
	latexmk -c $(ALLTEXFILES)

clean-all:
	latexmk -C $(ALLTEXFILES)
	$(RM) $(TIKZ_CACHE)/* $(TIKZ_STAMP)

index.html: FORCE_MAKE
	git checkout master
	cp misc/index.start.html index.html
	for branch in `git branch --list --no-column |grep -v master` ; do \
		echo "<li>$$branch: <a href=\"branches/$$branch/open-logic-debug.pdf\">debug</a> | <a href=\"branches/$$branch/open-logic-complete.pdf\">complete</a></li>" >> index.html ;\
	done 
	echo "</ol>" >> index.html
	echo "<h2>Parts, Chapters, Sections</h2>" >> index.html
	misc/htmltoc content content | sed "1d" >> index.html
	echo "<p>Generated from Git revision <code>" >> index.html
	grep shash .git/gitHeadInfo.gin |sed 's/[^{]*{\([^}]*\)},/\1/' >>index.html
	grep authsdate .git/gitHeadInfo.gin |sed 's/[^{]*{\([^}]*\)},/(\1)/' >> index.html
	echo "</code></p></div></div></div></body></html>" >> index.html
