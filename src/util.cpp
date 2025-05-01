// util.cpp

#include "util.hpp"

// Wrapper for osdialog_file that returns a string and frees allocated memory
std::string openFileDialog(osdialog_file_action action, const std::string &defaultFolder, const std::string &defaultFilename,
                           osdialog_filters *filters = nullptr)
{
    if (char *path = osdialog_file(action, defaultFolder.c_str(), defaultFilename.c_str(), filters))
    {
        std::string result(path);
        std::free(path);
        return result;
    }
    return "";
}

// Wrapper for copying a file in binary mode from source to destination
bool copyFile(const std::string &sourcePath, const std::string &destinationPath)
{
    INFO("Copying file from %s to %s", sourcePath.c_str(), destinationPath.c_str());

    // Open the source file in binary mode
    std::ifstream sourceFile(sourcePath, std::ios::binary);
    if (!sourceFile.is_open())
    {
        WARN("Error: Unable to open source file: %s", sourcePath.c_str());
        return false;
    }

    // Open the destination file in binary mode
    std::ofstream destFile(destinationPath, std::ios::binary);
    if (!destFile.is_open())
    {
        WARN("Error: Unable to create or open destination file: %s", destinationPath.c_str());
        return false;
    }

    // Copy the contents from the source file to the destination file
    destFile << sourceFile.rdbuf();

    // Explicitly check if the file write operation failed
    if (destFile.fail() || destFile.bad())
    {
        WARN("Error: Failed to write to destination file: %s", destinationPath.c_str());
        return false;
    }

    return true;
}