import argparse, terminal, random, os
import strformat, httpclient, base64, json, re
import nimlibxlsxwriter/xlsxwriter, strutils, times

# Worksheet name cannot contain invalid characters: '[ ] : * ? / \'
proc cleansn(sheetname: string): string =
  result = sheetname.replace(re"[\[\]:\*\?/\\]+", "-")
  result = result.replace(re"[']+", "\"")
  const AllChars = {'\x20'..'\x7e'}
  if result.len > 30:
    result = result[0..29]
    if result[^1] notin AllChars:
      var last = result.len - 1
      while result[last] notin AllChars:
        last -= 1
      var lenx = result.len-1 - last
      var remainder = lenx mod 3
      return result[0..result.len-1-remainder] 
    return result
  if result.len == 0:
    return "nil"
  return result

proc savedata(mail: string, key: string, query: string, rules: string, size: string, output: string): void =

  var fields: string = "host,ip,port,domain,title,country,province,city"
  var client = newHttpClient()

  if query.len != 0:
    var b64_query: string = base64.encode(query)
    var api_query: string = "https://fofa.so/api/v1/search/all?email={mail}&key={key}&qbase64={b64_query}&size={size}&fields={fields}".fmt
    var result = parseJson(client.getContent(api_query))["results"]
    var workbook: ptr lxw_workbook = workbook_new(output)
    var worksheet: ptr lxw_worksheet = workbook_add_worksheet(workbook, "data")
    var format: ptr lxw_format = workbook_add_format(workbook)
    format_set_bold(format)

    var title = fields.split(",")
    for i in low(title)..high(title):
      discard worksheet_write_string(worksheet, 0, lxw_col_t(i), title[i], nil)

    for i in 0..<len(result):
      for j in 0..<len(result[i]):
        discard worksheet_write_string(worksheet, lxw_col_t(i + 1), lxw_col_t(j), result[i][j].getStr(), nil)
    discard workbook_close(workbook)
    echo "[*] query {query} done! ({len(result)})".fmt

  if rules.len != 0:
    echo "[+] rules: {rules}".fmt
    var rfile: File
    rfile = open(rules, fmRead)
    var workbook: ptr lxw_workbook = workbook_new(output)
    var format: ptr lxw_format = workbook_add_format(workbook)
    format_set_bold(format)
    for query in rfile.lines:
      try:
        var b64_query: string = base64.encode(query)
        var api_query: string = "https://fofa.so/api/v1/search/all?email={mail}&key={key}&qbase64={b64_query}&size={size}&fields={fields}".fmt
        var result = parseJson(client.getContent(api_query))["results"]
        var worksheet: ptr lxw_worksheet = workbook_add_worksheet(workbook, cleansn(query))
        var title = fields.split(",")
        for i in low(title)..high(title):
          discard worksheet_write_string(worksheet, 0, lxw_col_t(i), title[i], nil)
        for i in 0..<len(result):
          for j in 0..<len(result[i]):
            discard worksheet_write_string(worksheet, lxw_col_t(i + 1), lxw_col_t(j), result[i][j].getStr(), nil)
        echo "[*] query {query} done! ({len(result)})".fmt
      except:
        echo "Unknown exception!"
        raise
    discard workbook_close(workbook)

  
proc auth(mail: string, key: string, query: string, rules: string, size: string, output: string): void =
  var authurl: string = "https://fofa.so/api/v1/info/my?email={mail}&key={key}".fmt
  var client = newHttpClient()
  for i in 1..3:
    if not contains(client.request(authurl).body, "401 Unauthorized"):
      savedata(mail, key, query, rules, size, output)
      break
    elif i < 3:
      continue
    else:
      echo "[-] 401 Unauthorized, make sure email and apikey is correct."
      quit()
    
proc color_banner(): void =
  let color = [fgRed, fgGreen, fgYellow, fgBlue, fgMagenta, fgCyan, fgWhite]
  let ascii_banner = """
      ░░░░▐▐░░░  dMMMMMP .aMMMb  dMMMMMP .aMMMb 
 ▐  ░░░░░▄██▄▄  dMP     dMP"dMP dMP     dMP"dMP 
  ▀▀██████▀░░  dMMMP   dMP dMP dMMMP   dMMMMMP  
  ░░▐▐░░▐▐░░  dMP     dMP.aMP dMP     dMP dMP   
 ▒▒▒▐▐▒▒▐▐▒  dMP      VMMMP" dMP     dMP dMP
https://github.com/inspiringz/nim-practice
  """
  randomize()
  stdout.styledWrite(sample(color), "\n{ascii_banner}\n".fmt)

when isMainModule:
  let begin_time = times.cpuTime()
  color_banner()

  let p = newParser:
    help("\neg: ./fofa -m <fofa_email_account> -k <fofa_api_key> -q '/login.rsp' -s 10000")
    option("-m", "--mail", default=some("cnno.1@protonmail.com"), help="fofa email account")
    option("-k", "--key", default=some("86b1a3ae6a597782a0394041c7d1908c"), help="fofa api key")
    option("-q", "--query", default=some(""), help="query string")
    option("-f", "--file", default=some(""), help="batch query rules file")
    option("-s", "--size", default=some("10000"), help="export data volume")
    option("-o", "--output", default=some("data.xlsx"), help="output filename / absolute path")
  
  let cmdline = os.commandLineParams()
  if cmdline.len <= 1:
    echo p.help
    quit()

  var 
    args = p.parse(cmdline)
    mail: string = args.mail
    key: string  = args.key
    query: string = args.query
    size: string = args.size
    rules: string
    output: string

  let current_dir = os.getCurrentDir()

  if args.file.len != 0:
    if contains(args.file, '\\') or contains(args.file, '/'):
      rules = args.file
    else:
      rules = os.joinPath(current_dir, args.file)
  
  if contains(args.output, '\\') or contains(args.output, '/'):
    output = args.output
  else:
    output = os.joinPath(current_dir, args.output)
  
  echo &"[+] email: {mail}"
  echo &"[+] key: {key}"

  auth(mail, key, query, rules, size, output)
  
  echo &"[+] output: {output}"
  let cost_time: float = times.cpuTime() - begin_time
  echo "[+] cost: ", cost_time.formatFloat(ffDecimal, 4), " seconds"

  
