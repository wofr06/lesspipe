if ( $?LESSOPEN && { eval 'test ! -z "$LESSOPEN"' } ) then
  :
else
  if ( -x __BINDIR__/lesspipe.sh ) then
    setenv LESSOPEN "||__BINDIR__/lesspipe.sh %s"
  endif
endif
