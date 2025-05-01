// util.hpp

#pragma once
#include <rack.hpp>
#include <osdialog.h>
#include <string>  // for std::string
#include <cstdlib> // for std::free()
#include <fstream> // for ifstream(), ofstream()
// #include <iostream> // for std::cout

// Wrapper for osdialog_file that returns a string and frees allocated memory
std::string openFileDialog(osdialog_file_action action, const std::string &defaultFolder, const std::string &defaultFilename,
                           osdialog_filters *filters);

bool copyFile(const std::string &sourcePath, const std::string &destinationPath);