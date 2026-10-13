find_program(CLANGD_EXECUTABLE NAMES clangd)
if (CLANGD_EXECUTABLE)
    file(GENERATE
    OUTPUT ${CMAKE_SOURCE_DIR}/.clangd
    CONTENT "CompileFlags:\n  CompilationDatabase: ${CMAKE_BINARY_DIR}\n"
  )
endif()