# Spike 97: do the outside libraries and clients run in a NativeAOT build?

Issue 97 (parent 95). Branch `feature/97-aot-library-spike`. Date 21 Nov 2026. Every figure below was measured by the spike author in this worktree; nothing is quoted from documentation.

Setup: .NET SDK image `mcr.microsoft.com/dotnet/sdk:11.0` (runtime 11.0.0), clang and zlib1g-dev, `PublishAot=true`, `InvariantGlobalization=true` (as the trial host `hosts/api-aot` has it), `-p:TrimmerSingleWarn=false`, linux (arm64 image on this Mac), final image `runtime-deps:11.0`. Package versions are those of `Directory.Packages.props` (Elastic.Clients.Elasticsearch 9.5.3, ClosedXML 0.105.1, JwtBearer 11.0.0). Elasticsearch ran as `elastic/elasticsearch:9.2.3` (the compose version) with security on and basic auth; Gotenberg as `gotenberg/gotenberg:8`. Containers `spike97-es` and `spike97-gotenberg` were removed afterwards.

The spike is one project, `spikes/aot-libraries/Spike.csproj`. It links the domain files **verbatim** (no file under `domains/`, `shared/` or `hosts/` was edited). Two publishes:

- `-p:Variant=asis`: the four JSON clients and the search index exactly as the domains have them. Log: `publish-asis.log`, run: `run-asis.log`.
- default (`sg`): copies in `spikes/aot-libraries/Sg/` with source-generated JSON. Log: `publish-sg.log`, run: `run-sg.log`.

## Result

| Item | Verdict | Publish warnings (distinct lines, measured) | Evidence |
|---|---|---|---|
| 1 Elasticsearch client | **Works with change**: the typed search fails as written; it works once the client is given a source-generated serializer for the document type. Index, bulk, scroll work unchanged | as written: 0 from the Elastic code; with the change: 0 | as written `docker run ... spike97-asis es` gave `FAIL es: threw :: SearchUnavailableException: Elasticsearch could not be reached: UnexpectedTransportException`; with the change (default variant) `PASS es: search teacher 'ali' ... :: 900001:Ali Raza\|900002:Alina Khan` and 11 es lines PASS |
| 2 ClosedXML | **Does NOT meet the zero-warning bar**: the tested write and read-back are correct (byte-identical to a JIT run on the same image), but publish carries 1 IL2090 trim warning inside ClosedXML. Decided: replaced by our own writer (#112) | 1 | `PASS xlsx: ...` 10 lines; `sheet1.xml, styles.xml, workbook.xml, sharedStrings.xml IDENTICAL (JIT linux vs AOT linux)`; the warning: `ILC : Trim analysis warning IL2090: ClosedXML.Utils.DescribedEnumParser`1.ParseEnumDescriptions()` |
| 3 JwtBearer (FirebaseVerifier) | **Works unchanged**, discovery and JWKS parsing included | 0 | 15 `PASS jwt:` lines, incl. `discovery document and JWKS were fetched and parsed` |
| 4a-1 Firebase accounts JSON (`GoogleFirebaseAccounts`) | **Works with change**: as written it throws at run time; with records and a `JsonSerializerContext` the bodies equal the reflection output | as written: 4 sites; with the change: 0 | as written `FAIL firebase: threw :: System.InvalidOperationException: Reflection-based serialization has been disabled`; with the change 8 `PASS firebase:` lines incl. `lookup body :: {"email":["owner@example.invalid"]}` |
| 4a-2 FCM JSON (`FcmPushSender`) | **Works with change** (same) | as written: 2 sites; with the change: 0 | as written `FAIL fcm: threw ...`; with the change 11 `PASS fcm:` lines incl. `send body byte-equal to reflection output` |
| 4a-3 Notifier JSON (`Notifier`) | **Works with change** (same) | as written: 3 sites; with the change: 0 | as written `FAIL notifier: threw ...`; with the change 5 `PASS notifier:` lines incl. `run-weekly body :: {"reminder_id":3,"dry_run":true,"triggered_by":900001}` |
| 4a-4 Google Sheets JSON (`GoogleSheets`) | **Works with change** (same) | as written: 2 sites; with the change: 0 | as written `FAIL sheets: threw ...`; with the change 6 `PASS sheets:` lines incl. `write body :: {"range":"Winners!A2",...,"values":[["First",923101,null],...` |
| 4b Gotenberg renderer | **Works unchanged** (it sends multipart, no JSON) | 0 | `PASS gotenberg: landscape render is a PDF :: 15989 bytes` (and `%PDF` check inside the renderer) |
| 4c YouTube feed | **Works unchanged** (it reads Atom XML, not JSON; `XDocument`/`XmlReader`) | 0 | 3 `PASS youtube:` lines |

Totals of the final default publish: 1 distinct warning (the ClosedXML one). Totals of the as-written publish: 45 (the same ClosedXML one plus 44 JSON ones). MSBuild prints a Roslyn analyzer line and an ILC line for each JSON site, so one site is two lines per code (IL2026 and IL3050); the 44 are 11 call sites x 2 codes x 2 sources. Native runs of the default publish: `run-sg.log` (first build of the final code, all six items including Elasticsearch and Gotenberg): 72 PASS, 0 FAIL. After the last edit (a per-client try/catch around the JSON item, so one failing client does not hide the others) both images were rebuilt: `run-sg-nocontainers.log` (json, jwt, xlsx, youtube): 58 PASS, 0 FAIL; `run-asis-nocontainers.log`: all four JSON clients `FAIL ... threw` as written, jwt, xlsx and youtube pass. Elasticsearch and Gotenberg were not re-run on the last rebuild (their source did not change). Counts per client above are from `run-sg.log` (`awk` per section: json 30, jwt 15, xlsx 10, youtube 3, es 11, gotenberg 3).

Important: the JSON failures are **run-time**, not publish-time failures. With `PublishAot=true` reflection serialization is switched off (`dynamic code supported: False`, and the failure also appears in a `dotnet build` JIT run of the same project), so the code compiles, publishes, and then throws on the first request.

## What a domain conversion must do

### 1 Elasticsearch (`domains/search/api`)
- What breaks: `ElasticSearchIndex.SearchAsync` reads documents into the nested type `IndexedDocument`. The client's default source serializer uses reflection. Evidence from a direct call in the native binary (`SPIKE_DIAG=1`): `System.NotSupportedException: Deserialization of types without a parameterless constructor ... Type 'Spike97.EsItem+Doc'`, wrapped as `UnexpectedTransportException`, which the domain code turns into "Elasticsearch could not be reached", so a user would see "search is down", not a crash. The raw JSON calls (`ElasticSearchIndex.Writer.cs`: HEAD, PUT mapping, `_bulk`, scroll, clear scroll, all through `Transport.RequestAsync<StringResponse>` and `JsonNode`) work unchanged. The typed request objects (`BoolQuery`, `MatchQuery`, `TermsQuery`, `SearchRequest`, `SourceFilter`) serialize fine: the server answered them in the native run.
- Change (applied in `Sg/ElasticSearchIndex.cs`, 5 lines): build the client with a source serializer taking the context, `new ElasticsearchClientSettings(new SingleNodePool(url), sourceSerializer: (_, s) => new DefaultSourceSerializer(s, SearchContext.Default, _ => { }))`; add `[JsonSerializable(typeof(ElasticSearchIndex.IndexedDocument))] partial class SearchContext : JsonSerializerContext`; put `[JsonPropertyName("id")]` and `[JsonPropertyName("name")]` on `IndexedDocument` (explicit, so no naming-policy guess). The constructor of `ElasticsearchClientSettings(Uri)` has no source-serializer parameter; the `NodePool` constructor does.
- Zero build warnings come from the Elastic assembly (the package is marked trimmable and AOT compatible); none were seen.
- Server 9.2.3 with client 9.5.3 worked (no media-type error), basic auth worked, a wrong password gave `Elasticsearch answered 401` and an unreachable host gave `SearchUnavailableException`, as the unit tests expect.

### 2 ClosedXML (`domains/platform/api`)
- `ReportXlsx.Build` runs unchanged. Tested inputs: a `=SUM(1+1)` text (stored as text, no `<f>` element in `sheet1.xml`), a surrogate pair and Arabic text, 33000 characters (cut to 32767), a number, a decimal, a float, a bool, a control character (dropped), a sheet title with forbidden characters, null and empty cells, a second section. The workbook was read back with `XLWorkbook` inside the native binary and unzipped.
- `AdjustToContents` (font measuring) works with no font in the `runtime-deps` image. Column widths differ from a JIT run on the Mac (6.085625 against 6.282054 for column 2) because the Mac has fonts; against a JIT run on Linux (`sdk:11.0` image, `dotnet Spike97.dll`) every compared part is identical, so native does not change the output. The `mcr.microsoft.com/dotnet/aspnet:11.0` image (the one `hosts/api/Dockerfile` runs on) has no `fc-list` and no `/usr/share/fonts` or `/usr/local/share/fonts` (measured with `docker run --rm ... aspnet:11.0 sh -c 'which fc-list; ls /usr/share/fonts ...'`), so widths there match the native ones. The Linux comparison was repeated against the `report.xlsx` of the last rebuilt native image: all four parts IDENTICAL.
- Remaining warning: `IL2090` in `ClosedXML.Utils.DescribedEnumParser<T>.ParseEnumDescriptions()` (reads enum fields by reflection; the package does not annotate `T`). It did not break the write path or the read-back path tested here.
- Traced afterwards (measured, on the spike branch): the warned code has one use, the enum `XLProtectionAlgorithm.Algorithm`, reached only by sheet or workbook protection. `ReportXlsx.Build` sets no protection and cannot reach it, and a native run of the protected path works, because the compiler keeps an enum's fields. But the native compiler has no per-library or per-member suppression: the only working form is switching IL2090 off for the whole publishing host, which also hid two warnings of our own in the spike. ClosedXML is 23.3 MB of the spike's 55.3 MB native binary.
- **Decided (Asif, 21 Nov 2026): ClosedXML is replaced by a small writer of our own for this one report layout.** Issue #112.

### 3 JwtBearer (`domains/identity/api`)
- `FirebaseVerification` and `FirebaseVerifier` ran unchanged. Production mode used `Authority` as the domain does, with a stub backchannel serving the discovery document and a JWKS made from a local RSA key (the repo's own test replaces the configuration manager with a static one, so it never parses these; the spike does). Tokens were signed by hand (RS256, `kid k1`), not with the library.
- Asserted and passing in the native binary: valid token (uid, email, `email_verified` true as a JSON boolean, name); `email_verified` sent as a string is not verified; numeric `name` ignored; no email gives `NoEmail`; wrong key, expired, other issuer, other audience, `iat` in the future without `nbf` (the `OnTokenValidated` event) and an unsigned token in production are all refused; no header is `NoCredentials`; emulator mode (unsigned token plus a stub `accounts:lookup`) gives the verified identity and a lookup for another uid is refused.
- No change needed. `JsonEncodedText`, `JsonDocument` and the `[GeneratedRegex]` are already AOT safe.

### 4 JSON of the outside clients
Today all four reflection-serialize: anonymous types (`GoogleFirebaseAccounts`, `Notifier`, `GoogleSheets`), `Dictionary<string, object>` (`FcmPushSender`, `GoogleSheets` JWT claims), `JsonContent.Create(object)` (`GoogleSheets.WriteAsync`). The sites (all warned as IL2026 and IL3050): `GoogleFirebaseAccounts.cs` lines 102, 120, 202, 203; `FcmPushSender.cs` 128, 302; `Notifier.cs` 38, 41, 44; `GoogleSheets.cs` 53, 212. Reading is by `JsonDocument` or `JsonNode` everywhere and needs no change.

The change (in `Sg/`, one file `WireJson.cs` plus the call sites): one record per body with `[JsonPropertyName]` in the order the old code wrote, one `JsonSerializerContext` (`WireContext`) listing them, and the typed overloads (`JsonSerializer.Serialize(value, WireContext.Default.X)`, `JsonContent.Create(value, WireContext.Default.X)`).

Per client:
- **Firebase accounts**: bodies `{"email":["..."]}` and `{"localId":"..."}`, the JWT header and claims. Output equals the reflection output; the JWT signature verifies with the public key; `EMAIL_NOT_FOUND` still maps to null.
- **FCM**: `Dictionary<string, object>` was replaced by records (`FcmEnvelope` and its parts); `message.Data` is copied into a `Dictionary<string, string>`. Output is byte-identical to reflection, including escapes (`"`, `é`). Reading error bodies (`Classify`) uses `JsonDocument` and was unchanged and passing. Keeping `Dictionary<string, object>` would need every runtime type behind `object` (nested dictionaries, the concrete type of `Data`) registered in the context; the records avoid that trap. That alternative was not run.
- **Notifier**: bodies `{"reminder_id":3,"dry_run":true,"triggered_by":900001}` (the exact string the existing test asserts), `send-test`, and `update` with `IReadOnlyDictionary<string, JsonElement>` (a nested object and an array inside) all round-trip. The answer is passed through as text.
- **Google Sheets**: the `values` cells are `object?`. The callers (`AdminQuizPublish.cs` lines 148, 162, 184) put only `string`, `long` and `null`, as `object?[]` or `List<object?>` inside an `IReadOnlyList<IReadOnlyList<object?>>`. The context lists `string` and `long` and the body equals the string `GoogleSheetsWire.Tests` asserts: `["First",923101,null]`, and non-ASCII text stays escaped like before. A cell of any other runtime type (for example `double` or `bool`) would throw under source generation: not run, but it follows from how `object` is serialized; the callers do not do it today.
- **Gotenberg**: no JSON. `MultipartFormDataContent` and `ReadAsByteArrayAsync`. Real container: landscape and portrait PDFs, 15989 bytes, `%PDF`; an unreachable address returns a failed `Result`.
- **YouTube**: no JSON; Atom parsed with `XmlReader` (DTD prohibited) and `XDocument`. Recorded-shape feed taken from `db/tests/YouTubeFeedTests.cs`: entry decoded, an entry with no title skipped, address `...?channel_id=UC%20synthetic%261`, a DOCTYPE refused. No warning.

## What was not tested

- The real services: Google (token endpoint, Identity Toolkit, FCM, Sheets), YouTube and the Firebase emulator itself. All answers came from stubs shaped like the repo's own tests. The "UNVERIFIED shape" notes in the domain files still stand.
- JwtBearer against Google's real discovery document and key rotation; only a stub with the same shape.
- Entity Framework, Npgsql with the 10 domain contexts, minimal-API JSON responses (`Results.Json(Dictionary<string, object>)` appears in many features, for example `notifications/api/features/class-events-list/ClassEventsList.cs`), request body binding, the `PeriodicWorker`, logging source generators and the host as a whole. This spike covers only the libraries listed in the issue; the many reflection `Results.Json` calls are a separate, larger conversion item.
- ClosedXML paths other than writing this report layout and reading it back (no formulas, charts, images, pivot tables, `XLWorkbook.Load` of a foreign file). Which ClosedXML code reaches the IL2090 warning was not traced.
- Elasticsearch: a cluster with TLS, an index of real size, scroll over more than one page (the test had 5 documents, 1 scroll page), the 5 and 30 second timeouts firing, and Elasticsearch 8 servers.
- Other architectures or an `x64` build: the images were arm64 on this Mac. Binary size and start time were not measured.
- A JIT-versus-native diff of Gotenberg and Elasticsearch outputs beyond the asserted values.
- A replacement for ClosedXML is not built or measured here; issue #112 specifies it.

## How to repeat

```
docker build --progress=plain -f spikes/aot-libraries/Dockerfile --build-arg VARIANT=sg   -t spike97-sg   .
docker build --progress=plain -f spikes/aot-libraries/Dockerfile --build-arg VARIANT=asis -t spike97-asis .
docker run --rm spike97-sg json jwt xlsx youtube       # no container needed
# es and gotenberg: start spike97-* containers on a user network, set SPIKE_ES_URL, SPIKE_ES_PASSWORD, SPIKE_GOTENBERG_URL
```

Files: `spikes/aot-libraries/` (project, Dockerfile, `Sg/`, `publish-*.log`, `run-*.log`), kept on the local branch `spike/97-aot-libraries`, which is not for merging. The images `spike97-*` were removed after the runs.
