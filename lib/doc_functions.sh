shared_resources() {
    mkdir -p $1/resources/
    cp -r $src/resources/* $1/resources/
}


assemble_content() {
    echo "assembling $1"
    md=`basename $1 | sed 's:_INDEX\.:\.:'`
    markdown-pp $1 -o $tmp/$md
}

assemble_resources() {
    new=`echo $1 | sed 's/\(.*\)\/resources\/images\(.*\)/resources\/images\/\1\2/'`
    newfull=$2/$new
    mkdir -p `dirname $newfull`
    cp $1 $newfull
}

make_html() {
    cd $TMPBASE/$lang
    name=$1
    subdir=$2
    mkdir -p ${target}/${subdir}/html
    shared_resources ${target}/${subdir}/html
    for res in `grep '(resources/images' ${name}.md | sed 's/.*resources\/images\/\([^)]*\)).*/resources\/images\/\1/'`; do
        mkdir -p ${target}/${subdir}/html/`dirname $res`
        cp $res ${target}/${subdir}/html/$res
    done
    echo "compiling $name.md to html"
    chapters="bookinfo.md ${name}.md"
    css="./resources/css/dhis2.css"
    template="./resources/templates/dhis2_template.html"
    thanks=""
    if [ -f "./resources/i18n/thanks/${name}_${lang}.html" ]; then
        thanks=" -B ./resources/i18n/thanks/${name}_${lang}.html "
    fi
    pandoc ${thanks} ${chapters} -c ${css} --template="${template}" --toc -N --section-divs -t html5 -o ${target}/${subdir}/html/${name}_full.html

    cd ${target}/${subdir}/html/
    # fix the section mappings in the full html file
    echo "remapping the section identifiers"
    id_mapper ${name}_full.html
    # split the full html file into chunks
    echo "splitting the html file into chunks"
    chunked_template="$tmp/resources/templates/dhis2_chunked_template.html"
    chunker ${name}_full.html ${chunked_template}


}

make_pdf() {
    cd $TMPBASE/$lang
    name=$1
    subdir=$2
    echo "making pdf in $PWD"
    mkdir -p ${target}/${subdir}
    echo "compiling $name.md to pdf"
    chapters="bookinfo.md ${name}.md"
    css="./resources/css/dhis2_pdf.css"
    template="./resources/templates/dhis2_template.html"
    thanks=""
    if [ -f "./resources/i18n/thanks/${name}_${lang}.html" ]; then
        thanks=" -B ./resources/i18n/thanks/${name}_${lang}.html "
    fi
    pandoc ${thanks} ${chapters} -c ${css} --template="${template}" --toc -N --section-divs --pdf-engine=weasyprint -o ${target}/${subdir}/${name}.pdf
}

assemble(){
    name=$1

    # copy resources and assembled markdown files to temp directory
    shared_resources $tmp
    cp $src/content/common/bookinfo.md $tmp/
    cd $src

    # copy resources and assembled markdown files to temp directory
    for f in ${name}_INDEX.md; do
        #echo "file: $f"
        assemble_content $f
    done

    for path in `grep "INCLUDE" ${name}_INDEX.md | sed 's/[^"]*"//' | sed 's/[^/]*"//' | sort -u`; do
      for r in `find $path -type f | grep "resources/images"`; do
          # echo "resource: $r"
          assemble_resources $r $tmp
      done
    done

}

update_localizations(){
    name=$1
    cd $TMPBASE


    # check for the transifex environment
    if [ ${LOCALISE} -eq 1 ]; then
       mkdir -p .tx
       cp en/resources/i18n/transifex-config .tx/config
       # <tx-project>.<resource-name>
       txproject=`git ls-remote --heads origin | grep $(git rev-parse HEAD) | cut -d / -f 3`
       if [ ${txproject} == "" ]; then
           txproject="master"
       fi
       sed -i "s/<tx-project>/${txproject//.}/" .tx/config
       sed -i "s/<name>/${name}/" .tx/config
       sed -i "s/<resource-name>/${name//_/-}/" .tx/config
       # Use "prettier" to ensure each markdown text block is on a single line
       # This is necessary to ensure that blocks are correctly parsed by transifex.
       prettier --prose-wrap never --write en/${name}.md

       # Push source updates to transifex
       tx push -s

    else
       echo "INFO: Transifex not configured. Source files will not be pushed."
    fi

}

pull_translations(){
    name=$1
    cd $TMPBASE


    # check for the transifex environment
    if [ ${LOCALISE} -eq 1 ]; then
       mkdir -p .tx
       cp en/resources/i18n/transifex-config .tx/config
       # <tx-project>.<resource-name>
       txproject=`git ls-remote --heads origin | grep $(git rev-parse HEAD) | cut -d / -f 3`
       if [ ${txproject} == "" ]; then
           txproject="master"
       fi
       sed -i "s/<tx-project>/${txproject//.}/" .tx/config
       sed -i "s/<name>/${name}/" .tx/config
       sed -i "s/<resource-name>/${name//_/-}/" .tx/config
       # Use "prettier" to ensure each markdown text block is on a single line
       # This is necessary to ensure that blocks are correctly parsed by transifex.
       # WE ARE NOT PUSHING TO TRANSIFEX IN THIS FUNCTION, SO STRICTLY SPEAKING
       # WE DON'T NEED THIS HERE
       prettier --prose-wrap never --write en/${name}.md

       # Pull the translations from transifex
       # only French at the moment - should be refactored for multiple languages
       tx pull -l fr
       ln -s ../en/resources fr/resources

    else
       echo "INFO: Transifex not configured. Localised versions will not be generated."
    fi

}

build_docs(){
    name=$1
    subdir=$2
    selection=$3
    lang=$4
    locale=$5

    cd $TMPBASE/$lang
    echo "Working in $PWD"

    target="$localisation_root/$lang"
    mkdir -p $target

    gitbranch=`git ls-remote --heads origin | grep $(git rev-parse HEAD) | cut -d / -f 3`
    githash=`git rev-parse --short HEAD`
    gitdate=`git show -s --format=%ci $githash`
    gityear=`date -d "${gitdate}" '+%Y'`
    gitmonth=`LC_TIME=${locale}.utf8 date -d "${gitdate}" '+%B'`
    sed -i "s/<git-branch>/$gitbranch/" bookinfo*.md
    sed -i "s/<git-hash>/$githash/" bookinfo*.md
    sed -i "s/<git-date>/$gitdate/" bookinfo*.md
    sed -i "s/<git-year>/$gityear/" bookinfo*.md
    sed -i "s/<git-month>/$gitmonth/" bookinfo*.md

    if [ $selection == "html" ]
    then
      make_html $name $subdir
    elif [ $selection == "pdf" ]
    then
      make_pdf $name $subdir
    else
      make_html $name $subdir
      make_pdf $name $subdir
    fi

}
