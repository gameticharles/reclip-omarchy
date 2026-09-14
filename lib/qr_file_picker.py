#!/usr/bin/env python3
"""
qr_file_picker.py - Desktop Multi-File & Folder Picker Helper for ReClip Omarchy

Invokes native desktop pickers in order of desktop integration:
1. omarchy-file-select (native Omarchy XDG portal, supports --multiple and --directory)
2. zenity --file-selection (--multiple or --directory)
3. kdialog (--getopenfilename --multiple or --getexistingdirectory)
4. PyQt6 QFileDialog (getOpenFileNames or getExistingDirectory)
5. tkinter (askopenfilenames or askdirectory)

Prints selected absolute paths, one per line, to stdout.
"""

import os
import sys
import shutil
import argparse
import subprocess

def run_picker(is_directory=False):
    title = "Select Folder to Share via Wi-Fi" if is_directory else "Select File(s) to Share via Wi-Fi"

    # 1. Native Omarchy Portal Chooser
    omarchy_select = shutil.which("omarchy-file-select")
    if not omarchy_select and os.path.exists("/usr/share/omarchy/bin/omarchy-file-select"):
        omarchy_select = "/usr/share/omarchy/bin/omarchy-file-select"

    if omarchy_select:
        try:
            cmd = [omarchy_select, "--title", title]
            if is_directory:
                cmd.append("--directory")
            else:
                cmd.append("--multiple")
            res = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            if res.returncode == 0 and res.stdout.strip():
                valid = []
                for line in res.stdout.strip().splitlines():
                    p = line.strip()
                    if p and os.path.exists(p):
                        valid.append(os.path.abspath(p))
                if valid:
                    for v in valid:
                        print(v)
                    return 0
        except Exception:
            pass

    # 2. Zenity
    if shutil.which("zenity"):
        try:
            cmd = ["zenity", "--file-selection", f"--title={title}"]
            if is_directory:
                cmd.append("--directory")
            else:
                cmd.extend(["--multiple", "--separator=\n"])
            res = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            if res.returncode == 0 and res.stdout.strip():
                valid = []
                for line in res.stdout.strip().splitlines():
                    p = line.strip()
                    if p and os.path.exists(p):
                        valid.append(os.path.abspath(p))
                if valid:
                    for v in valid:
                        print(v)
                    return 0
        except Exception:
            pass

    # 3. Kdialog
    if shutil.which("kdialog"):
        try:
            if is_directory:
                cmd = ["kdialog", "--getexistingdirectory", os.path.expanduser("~")]
            else:
                cmd = ["kdialog", "--getopenfilename", os.path.expanduser("~"), "--multiple"]
            res = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            if res.returncode == 0 and res.stdout.strip():
                if is_directory:
                    p = res.stdout.strip()
                    if p and os.path.exists(p):
                        print(os.path.abspath(p))
                        return 0
                else:
                    for line in res.stdout.strip().split():
                        p = line.strip()
                        if p and os.path.exists(p):
                            print(os.path.abspath(p))
                    return 0
        except Exception:
            pass

    # 4. PyQt6 (standard Qt6 portal / native Wayland)
    try:
        from PyQt6.QtWidgets import QApplication, QFileDialog
        app = QApplication.instance()
        if not app:
            app = QApplication(["reclip-picker"])
        if is_directory:
            folder = QFileDialog.getExistingDirectory(
                None,
                title,
                os.path.expanduser("~")
            )
            if folder and os.path.exists(folder):
                print(os.path.abspath(folder))
                return 0
        else:
            files, _ = QFileDialog.getOpenFileNames(
                None,
                title,
                os.path.expanduser("~"),
                "All Files (*)"
            )
            if files:
                valid = [os.path.abspath(f) for f in files if os.path.exists(f)]
                if valid:
                    for v in valid:
                        print(v)
                    return 0
    except Exception:
        pass

    # 5. Tkinter Fallback
    try:
        import tkinter
        from tkinter import filedialog
        r = tkinter.Tk()
        r.withdraw()
        if is_directory:
            folder = filedialog.askdirectory(title=title)
            r.destroy()
            if folder and os.path.exists(folder):
                print(os.path.abspath(folder))
                return 0
        else:
            files = filedialog.askopenfilenames(title=title)
            r.destroy()
            if files:
                valid = [os.path.abspath(f) for f in files if os.path.exists(f)]
                if valid:
                    for v in valid:
                        print(v)
                    return 0
    except Exception:
        pass

    return 1

def main():
    parser = argparse.ArgumentParser(description="Desktop File/Folder Picker for ReClip")
    parser.add_argument("-d", "--directory", "--folder", action="store_true", help="Pick directory/folder instead of files")
    args = parser.parse_args()
    return run_picker(is_directory=args.directory)

if __name__ == "__main__":
    sys.exit(main())
