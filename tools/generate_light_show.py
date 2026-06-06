#!/usr/bin/env python3
import librosa
import numpy as np
import json
import argparse
import os

def extract_waveform(file_path, interval=0.1):
    print(f"Loading {file_path}...")
    y, sr = librosa.load(file_path)
    hop_length = int(sr * interval)
    rms = librosa.feature.rms(y=y, hop_length=hop_length, frame_length=hop_length*2)[0]
    if np.max(rms) > 0:
        rms = rms / np.max(rms)
    times = np.arange(len(rms)) * interval
    return list(zip(times, rms))

def generate_luau(data, show_name):
    steps = []
    groups = ['a', 'b', 'c', 'd']
    
    for t, v in data:
        if v > 0.8:
            for g in groups:
                steps.append(f"{{ {t:.2f}, '{g}', 'all', 0.1 }}")
        elif v > 0.6:
            if int(t * 10) % 2 == 0:
                steps.append(f"{{ {t:.2f}, 'a', 'all', 0.1 }}")
                steps.append(f"{{ {t:.2f}, 'c', 'all', 0.1 }}")
            else:
                steps.append(f"{{ {t:.2f}, 'b', 'all', 0.1 }}")
                steps.append(f"{{ {t:.2f}, 'd', 'all', 0.1 }}")
        elif v > 0.4:
            g = groups[int(t * 10) % 4]
            steps.append(f"{{ {t:.2f}, '{g}', 'all', 0.1 }}")
        elif v > 0.2:
            g = groups[int(t * 10) % 4]
            index = (int(t * 10) % 18) + 1
            steps.append(f"{{ {t:.2f}, '{g}', {index}, 0.1 }}")
    
    list_name = f"{show_name}Data"
    func_name = f"Get{show_name}Show"
    
    luau_lines = []
    luau_lines.append(f"-- Data generated from waveform analysis")
    luau_lines.append(f"LightShowConfig.{list_name} = {{")
    luau_lines.append("\t" + ",\n\t".join(steps))
    luau_lines.append("}")
    
    luau_lines.append(f"\nfunction LightShowConfig.{func_name}(): {{LightStep}}")
    luau_lines.append("\tlocal sequence = {}")
    luau_lines.append(f"\tfor _, data in ipairs(LightShowConfig.{list_name}) do")
    luau_lines.append("\t\ttable.insert(sequence, {")
    luau_lines.append("\t\t\tstartTime = data[1],")
    luau_lines.append("\t\t\tgroup     = data[2],")
    luau_lines.append("\t\t\tindex     = data[3],")
    luau_lines.append("\t\t\tduration  = data[4],")
    luau_lines.append("\t\t})")
    luau_lines.append("\tend")
    luau_lines.append("\treturn sequence")
    luau_lines.append("end")
    
    return "\n".join(luau_lines)

def main():
    parser = argparse.ArgumentParser(description="Convert MP3 waveform to Luau LightShow sequence")
    parser.add_argument("input", help="Path to the MP3 file")
    parser.add_argument("--name", help="Internal name for the show (e.g. IronCartilage)", required=True)
    parser.add_argument("--interval", type=float, default=0.1, help="Sampling interval in seconds (default: 0.1)")
    parser.add_argument("--output", help="Optional path to append the Luau code to")
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input):
        print(f"Error: File {args.input} not found.")
        return

    data = extract_waveform(args.input, args.interval)
    luau_code = generate_luau(data, args.name)
    
    if args.output:
        with open(args.output, "r") as f:
            content = f.read()
        
        if "return LightShowConfig" in content:
            new_content = content.replace("return LightShowConfig", f"{luau_code}\n\nreturn LightShowConfig")
            with open(args.output, "w") as f:
                f.write(new_content)
            print(f"Successfully appended {args.name} to {args.output}")
        else:
            print(f"Error: 'return LightShowConfig' not found in {args.output}")
    else:
        print("\n--- GENERATED LUAU CODE ---\n")
        print(luau_code)

if __name__ == "__main__":
    main()
