set(name mesh)
set(source_files ${name}.cc)
set(header_files)
set(libraries_to_link ${libinternet} ${libmobility} ${libwifi} ${libmesh} ${libapplications})
build_lib_example ("${name}" "${source_files}" "${header_files}" "${libraries_to_link}")

