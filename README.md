[Русский](README.ru.md)
# AWS IP Ranges to MikroTik Address-List

PowerShell script that downloads the official AWS IP ranges JSON and generates MikroTik RouterOS commands to fill an address-list. Output is split into `.txt` files of up to 2000 lines each, so you can copy-paste them into the MikroTik terminal manually.

## 🧩 Why I built this

I ran into this problem because of Roskomnadzor blocks. Game servers and matchmaking for **Warhammer 40,000: Darktide**, **Gray Zone Warfare** and **War Dogs** sit behind AWS infrastructure that was unreachable directly from my ISP. Instead of using clumsy workarounds (proxy on the console, per-game hacks, toggling VPN on and off), I routed only the AWS prefixes through a tunnel on my MikroTik and left everything else — including Russian services — going direct.

This script is what made that setup practical: it keeps the AWS address-list fresh without manual copy-paste of thousands of prefixes, so the games launch and matchmake normally, and the rest of the network keeps working as usual.

## 📋 What it does

1. Downloads `https://ip-ranges.amazonaws.com/ip-ranges.json`
2. Optionally filters by AWS region and/or service
3. Removes duplicates
4. Generates RouterOS commands: `/ip firewall address-list add list=<list> address=<prefix> comment="<comment>"`
5. Splits the output into files of 2000 lines max
6. Saves them to the specified folder (created if missing)

File names look like: `AWS-30-10-2026-1.txt`, `AWS-30-10-2026-2.txt`, ...

## ✅ Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Internet access to reach `ip-ranges.amazonaws.com`
- Write access to the output folder

## 🚀 Usage

Run the script: `.\Get-AwsRanges.ps1`

The script interactively asks for:

- **Address-list name** (Enter = `Madbaza`)
- **Comment** (Enter = `AMAZON`)
- **Output path** (Enter = `D:\AWS`)

You can also pass them directly to skip the prompts: `.\Get-AwsRanges.ps1 -AddressList Madbaza -Comment AMAZON -OutputDir "D:\AWS"`

## ⚙️ Parameters

| Parameter | Default | Description |
|---|---|---|
| `-AddressList` | `Madbaza` | Target address-list name |
| `-Comment` | `AMAZON` | Comment added to every entry |
| `-OutputDir` | `D:\AWS` | Folder for generated files |
| `-FilterRegion` | — | Only include prefixes from this AWS region (e.g. `eu-central-1`) |
| `-FilterService` | — | Only include prefixes for this AWS service (e.g. `S3`, `EC2`) |
| `-ShowSyncInfo` | off | Print `syncToken`, `createDate` and total prefix count |
| `-MaxLinesPerFile` | `2000` | Max lines per output file |

## 📝 Example

`.\Get-AwsRanges.ps1 -FilterRegion eu-central-1 -ShowSyncInfo`

## 📥 Importing into MikroTik

1. Open the generated `.txt` file
2. Select all (`Ctrl+A`), copy (`Ctrl+C`)
3. Paste into the MikroTik terminal (WinBox or SSH)

Files are written **without BOM**, so the first command will execute correctly when pasted.

If you want to clear the list before importing, run this on the router first: `/ip firewall address-list remove [find list=Madbaza]`

## 📌 Notes

- Only IPv4 prefixes (`prefixes` array) are used. IPv6 (`ipv6_prefixes`) is not included.
- The script does not delete anything on the router — it only generates `add` commands.
- Duplicates are removed with `Sort-Object ip_prefix -Unique`.
