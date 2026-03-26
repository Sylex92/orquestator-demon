[CmdletBinding()]
param(
    [string]$Owner = "Sylex92",
    [string]$ProjectTitle = "Daemon Modernization",
    [string]$PrimaryRepo = "orquestator-demon"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function ConvertTo-NativeArgumentString {
    param([string[]]$Arguments)

    $quoted = foreach ($argument in $Arguments) {
        if ($argument -notmatch '[\s"]') {
            $argument
            continue
        }

        '"' + (($argument -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
    }

    return ($quoted -join " ")
}

function Format-GhCommandText {
    param([string[]]$Arguments)

    return "gh " + (ConvertTo-NativeArgumentString -Arguments $Arguments)
}

function Invoke-GhRaw {
    param([string[]]$Arguments)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "gh.exe"
    $startInfo.Arguments = ConvertTo-NativeArgumentString -Arguments $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $combinedOutput = @($stdout.Trim(), $stderr.Trim()) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output   = ($combinedOutput -join [Environment]::NewLine).Trim()
    }
}

function Invoke-GhText {
    param([string[]]$Arguments)

    $result = Invoke-GhRaw -Arguments $Arguments
    if ($result.ExitCode -ne 0) {
        throw "Command failed: $(Format-GhCommandText -Arguments $Arguments)`n$($result.Output)"
    }

    return $result.Output
}

function Invoke-GhJson {
    param([string[]]$Arguments)

    $raw = Invoke-GhText -Arguments $Arguments
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return $raw | ConvertFrom-Json
}

function Test-GhAuthentication {
    Write-Step "Validating GitHub CLI authentication"

    $authStatus = Invoke-GhRaw -Arguments @("auth", "status")
    if ($authStatus.ExitCode -ne 0) {
        throw @"
GitHub CLI is not authenticated.

Run this exact command and then execute the script again:
gh auth login --hostname github.com --web --scopes "repo,project,read:org"
"@
    }

    Write-Host $authStatus.Output

    if ($authStatus.Output -notmatch "Token scopes: .*'project'") {
        throw @"
GitHub CLI is authenticated, but the token is missing the required write scope for Projects v2.

Run this exact command and then execute the script again:
gh auth refresh -s project
"@
    }

    $projectProbe = Invoke-GhRaw -Arguments @("project", "list", "--owner", $Owner, "--limit", "1")
    if ($projectProbe.ExitCode -ne 0) {
        $refreshCommand = $null

        if ($projectProbe.Output -match "(?im)run:\s+(gh auth refresh[^\r\n]+)") {
            $refreshCommand = $Matches[1].Trim()
        }

        if ($projectProbe.Output -match "project" -and $refreshCommand) {
            throw @"
GitHub CLI is authenticated, but the token is missing the required project scope.

Run this exact command and then execute the script again:
$refreshCommand
"@
        }

        throw "Unable to validate project access for owner '$Owner'.`n$($projectProbe.Output)"
    }
}

function Get-OwnerNode {
    param([string]$Login)

    $query = @'
query($login: String!) {
  repositoryOwner(login: $login) {
    __typename
    login
    ... on Organization {
      id
    }
    ... on User {
      id
    }
  }
}
'@

    $response = Invoke-GhJson -Arguments @(
        "api", "graphql",
        "-f", "query=$query",
        "-F", "login=$Login"
    )

    $owner = $response.data.repositoryOwner

    if ($owner) {
        return [pscustomobject]@{
            Id    = $owner.id
            Login = $owner.login
            Type  = $owner.__typename.ToLowerInvariant()
        }
    }

    throw "Owner '$Login' was not found on GitHub."
}

function Get-ProjectsForOwner {
    param([string]$Login)

    $query = @'
query($login: String!) {
  repositoryOwner(login: $login) {
    __typename
    ... on Organization {
      projectsV2(first: 100) {
        nodes {
          id
          number
          title
          url
          closed
        }
      }
    }
    ... on User {
      projectsV2(first: 100) {
        nodes {
          id
          number
          title
          url
          closed
        }
      }
    }
  }
}
'@

    $response = Invoke-GhJson -Arguments @(
        "api", "graphql",
        "-f", "query=$query",
        "-F", "login=$Login"
    )

    return @($response.data.repositoryOwner.projectsV2.nodes)
}

function Get-OrCreateProject {
    param(
        [string]$OwnerLogin,
        [string]$OwnerId,
        [string]$Title
    )

    $existing = Get-ProjectsForOwner -Login $OwnerLogin |
        Where-Object { $_.title -eq $Title -and -not $_.closed } |
        Select-Object -First 1

    if ($existing) {
        Write-Step "Reusing existing project #$($existing.number): $Title"
        return [pscustomobject]@{
            Id     = $existing.id
            Number = [int]$existing.number
            Title  = $existing.title
            Url    = $existing.url
        }
    }

    Write-Step "Creating project '$Title'"

    $mutation = @'
mutation($ownerId: ID!, $title: String!) {
  createProjectV2(input: { ownerId: $ownerId, title: $title }) {
    projectV2 {
      id
      number
      title
      url
    }
  }
}
'@

    $response = Invoke-GhJson -Arguments @(
        "api", "graphql",
        "-f", "query=$mutation",
        "-F", "ownerId=$OwnerId",
        "-F", "title=$Title"
    )

    $project = $response.data.createProjectV2.projectV2

    return [pscustomobject]@{
        Id     = $project.id
        Number = [int]$project.number
        Title  = $project.title
        Url    = $project.url
    }
}

function Get-ProjectSnapshot {
    param(
        [string]$OwnerLogin,
        [int]$ProjectNumber
    )

    $query = @'
query($login: String!, $number: Int!) {
  repositoryOwner(login: $login) {
    __typename
    ... on Organization {
      projectV2(number: $number) {
        id
        title
        url
        fields(first: 50) {
          nodes {
            __typename
            ... on ProjectV2FieldCommon {
              id
              name
              dataType
            }
            ... on ProjectV2SingleSelectField {
              options {
                id
                name
              }
            }
          }
        }
        items(first: 100) {
          nodes {
            id
            content {
              __typename
              ... on Issue {
                id
                number
                title
                url
                repository {
                  name
                  nameWithOwner
                }
              }
            }
          }
        }
      }
    }
    ... on User {
      projectV2(number: $number) {
        id
        title
        url
        fields(first: 50) {
          nodes {
            __typename
            ... on ProjectV2FieldCommon {
              id
              name
              dataType
            }
            ... on ProjectV2SingleSelectField {
              options {
                id
                name
              }
            }
          }
        }
        items(first: 100) {
          nodes {
            id
            content {
              __typename
              ... on Issue {
                id
                number
                title
                url
                repository {
                  name
                  nameWithOwner
                }
              }
            }
          }
        }
      }
    }
  }
}
'@

    $response = Invoke-GhJson -Arguments @(
        "api", "graphql",
        "-f", "query=$query",
        "-F", "login=$OwnerLogin",
        "-F", "number=$ProjectNumber"
    )

    $project = $response.data.repositoryOwner.projectV2

    if (-not $project) {
        throw "Project #$ProjectNumber for '$OwnerLogin' was not found."
    }

    return $project
}

function Ensure-SingleSelectField {
    param(
        [string]$OwnerLogin,
        [int]$ProjectNumber,
        [string]$FieldName,
        [string[]]$Options
    )

    $fieldResponse = Invoke-GhJson -Arguments @(
        "project", "field-list", "$ProjectNumber",
        "--owner", $OwnerLogin,
        "--format", "json"
    )
    $existing = @($fieldResponse.fields) | Where-Object { $_.name -eq $FieldName } | Select-Object -First 1

    if ($existing) {
        $existingOptions = @($existing.options | ForEach-Object { $_.name })
        $missingOptions = $Options | Where-Object { $_ -notin $existingOptions }

        if ($existing.type -ne "ProjectV2SingleSelectField") {
            throw "Field '$FieldName' already exists but is not SINGLE_SELECT."
        }

        if (@($missingOptions).Count -gt 0) {
            Write-Warning "Field '$FieldName' already exists but is missing options: $($missingOptions -join ', '). Update it manually in the GitHub UI if needed."
        }
        else {
            Write-Step "Reusing field '$FieldName'"
        }

        return
    }

    Write-Step "Creating field '$FieldName'"

    Invoke-GhText -Arguments @(
        "project", "field-create", "$ProjectNumber",
        "--owner", $OwnerLogin,
        "--name", $FieldName,
        "--data-type", "SINGLE_SELECT",
        "--single-select-options", ($Options -join ",")
    ) | Out-Null
}

function Get-SingleSelectFieldLookup {
    param(
        [string]$OwnerLogin,
        [int]$ProjectNumber
    )

    $projectView = Invoke-GhJson -Arguments @(
        "project", "view", "$ProjectNumber",
        "--owner", $OwnerLogin,
        "--format", "json"
    )
    $fieldResponse = Invoke-GhJson -Arguments @(
        "project", "field-list", "$ProjectNumber",
        "--owner", $OwnerLogin,
        "--format", "json"
    )
    $itemResponse = Invoke-GhJson -Arguments @(
        "project", "item-list", "$ProjectNumber",
        "--owner", $OwnerLogin,
        "--format", "json"
    )
    $lookup = @{}

    foreach ($field in @($fieldResponse.fields)) {
        if ($field.type -eq "ProjectV2SingleSelectField") {
            $optionLookup = @{}

            foreach ($option in @($field.options)) {
                $optionLookup[$option.name] = $option.id
            }

            $lookup[$field.name] = [pscustomobject]@{
                Id      = $field.id
                Name    = $field.name
                Options = $optionLookup
            }
        }
    }

    return [pscustomobject]@{
        ProjectId = $projectView.id
        Fields    = $lookup
        Items     = @($itemResponse.items)
        Url       = $projectView.url
        Title     = $projectView.title
    }
}

function New-IssueBody {
    param(
        [string]$Objective,
        [string]$CurrentContext,
        [string]$Problem,
        [string]$Scope,
        [string[]]$AcceptanceCriteria,
        [string[]]$Deliverables,
        [string[]]$Risks
    )

    $body = @(
        "## Objetivo"
        $Objective
        ""
        "## Contexto actual"
        $CurrentContext
        ""
        "## Problema"
        $Problem
        ""
        "## Alcance"
        $Scope
        ""
        "## Criterios de aceptación"
    )

    foreach ($item in $AcceptanceCriteria) {
        $body += "- $item"
    }

    $body += ""
    $body += "## Entregables"

    foreach ($item in $Deliverables) {
        $body += "- $item"
    }

    $body += ""
    $body += "## Riesgos"

    foreach ($item in $Risks) {
        $body += "- $item"
    }

    return ($body -join "`n")
}

function Find-IssueByTitle {
    param(
        [string]$Repository,
        [string]$Title
    )

    $issues = Invoke-GhJson -Arguments @(
        "issue", "list",
        "--repo", $Repository,
        "--state", "all",
        "--limit", "1000",
        "--json", "id,number,title,url"
    )

    return @($issues) | Where-Object { $_.title -eq $Title } | Select-Object -First 1
}

function Get-OrCreateIssue {
    param(
        [string]$Repository,
        [hashtable]$Definition
    )

    $existing = Find-IssueByTitle -Repository $Repository -Title $Definition.Title
    if ($existing) {
        Write-Step "Reusing issue #$($existing.number): $($Definition.Title)"
        return $existing
    }

    Write-Step "Creating issue: $($Definition.Title)"

    $tempPath = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $tempPath -Value $Definition.Body -Encoding utf8

        $createdUrl = Invoke-GhText -Arguments @(
            "issue", "create",
            "--repo", $Repository,
            "--title", $Definition.Title,
            "--body-file", $tempPath
        )
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }

    $created = Find-IssueByTitle -Repository $Repository -Title $Definition.Title
    if (-not $created) {
        return [pscustomobject]@{
            number = [int]($createdUrl.TrimEnd("/") -split "/")[-1]
            title  = $Definition.Title
            url    = $createdUrl.Trim()
        }
    }

    return $created
}

function Find-ProjectItemIdByIssueUrl {
    param(
        [object[]]$Items,
        [string]$IssueUrl
    )

    $item = @($Items) |
        Where-Object { $_.content -and $_.content.url -eq $IssueUrl } |
        Select-Object -First 1

    if ($item) {
        return $item.id
    }

    return $null
}

function Ensure-IssueInProject {
    param(
        [string]$OwnerLogin,
        [int]$ProjectNumber,
        [string]$IssueUrl,
        [psobject]$ProjectLookup
    )

    $existingItemId = Find-ProjectItemIdByIssueUrl -Items $ProjectLookup.Items -IssueUrl $IssueUrl

    if ($existingItemId) {
        Write-Step "Issue already present in project: $IssueUrl"
        return [pscustomobject]@{
            ProjectId = $ProjectLookup.ProjectId
            ItemId    = $existingItemId
            Fields    = $ProjectLookup.Fields
            Lookup    = $ProjectLookup
        }
    }

    Write-Step "Adding issue to project: $IssueUrl"

    Invoke-GhText -Arguments @(
        "project", "item-add", "$ProjectNumber",
        "--owner", $OwnerLogin,
        "--url", $IssueUrl
    ) | Out-Null

    $refreshed = Get-SingleSelectFieldLookup -OwnerLogin $OwnerLogin -ProjectNumber $ProjectNumber
    $itemId = Find-ProjectItemIdByIssueUrl -Items $refreshed.Items -IssueUrl $IssueUrl

    if (-not $itemId) {
        throw "Issue '$IssueUrl' was added to the project but the item id could not be resolved afterwards."
    }

    return [pscustomobject]@{
        ProjectId = $refreshed.ProjectId
        ItemId    = $itemId
        Fields    = $refreshed.Fields
        Lookup    = $refreshed
    }
}

function Set-SingleSelectFieldValue {
    param(
        [string]$ProjectId,
        [string]$ItemId,
        [hashtable]$FieldLookup,
        [string]$FieldName,
        [string]$OptionName
    )

    if (-not $FieldLookup.ContainsKey($FieldName)) {
        throw "Field '$FieldName' is not available in the project."
    }

    $field = $FieldLookup[$FieldName]
    if (-not $field.Options.ContainsKey($OptionName)) {
        throw "Option '$OptionName' was not found in field '$FieldName'."
    }

    Invoke-GhText -Arguments @(
        "project", "item-edit",
        "--id", $ItemId,
        "--project-id", $ProjectId,
        "--field-id", $field.Id,
        "--single-select-option-id", $field.Options[$OptionName]
    ) | Out-Null
}

function Build-IssueDefinitions {
    $epics = @(
        @{
            Title    = "[EPIC] Inventario completo de los ~200 procesos"
            Priority = "P0"
            WorkType = "Epic"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody `
                -Objective "Construir un inventario confiable de todos los procesos del daemon, con dependencias, frecuencia y estado operativo." `
                -CurrentContext "Hoy el conocimiento esta repartido entre scripts, tareas programadas y conocimiento tacito del equipo." `
                -Problem "Sin inventario consolidado no se puede priorizar la modernizacion ni dimensionar dependencias criticas." `
                -Scope "Levantar catalogo base, metadata operativa y clasificacion inicial de procesos." `
                -AcceptanceCriteria @(
                    "Existe un listado unico con todos los procesos conocidos.",
                    "Cada proceso incluye frecuencia, owner, entradas, salidas y dependencias.",
                    "Se identifican procesos criticos, redundantes y obsoletos."
                ) `
                -Deliverables @(
                    "Inventario maestro de procesos.",
                    "Matriz de criticidad y dependencias.",
                    "Resumen ejecutivo de hallazgos."
                ) `
                -Risks @(
                    "Pueden existir procesos no documentados o manuales fuera del primer barrido.",
                    "La metadata tecnica puede variar entre ambientes."
                )
        }
        @{
            Title    = "[EPIC] Definir plataforma objetivo (ADR)"
            Priority = "P0"
            WorkType = "Epic"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody `
                -Objective "Definir la plataforma objetivo para el daemon y formalizar la decision en ADRs." `
                -CurrentContext "Existen tecnologias y modos de ejecucion heterogeneos sin una arquitectura objetivo aprobada." `
                -Problem "Sin decision arquitectonica explicita la migracion puede fragmentarse en soluciones inconsistentes." `
                -Scope "Recopilar drivers y restricciones, evaluar alternativas y documentar la recomendacion." `
                -AcceptanceCriteria @(
                    "Se documentan drivers de negocio, operacion, seguridad y costo.",
                    "Se comparan alternativas con criterios comunes.",
                    "Se aprueba un ADR con la plataforma objetivo."
                ) `
                -Deliverables @(
                    "ADR principal de plataforma objetivo.",
                    "Matriz comparativa de alternativas.",
                    "Lista de supuestos y decisiones abiertas."
                ) `
                -Risks @(
                    "Cambios de prioridad pueden invalidar supuestos.",
                    "La decision puede depender de capacidades no disponibles hoy."
                )
        }
        @{
            Title    = "[EPIC] Configuracion centralizada"
            Priority = "P1"
            WorkType = "Epic"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody `
                -Objective "Disenar una estrategia de configuracion centralizada, versionable y segura." `
                -CurrentContext "La configuracion actual puede estar dispersa en scripts, archivos locales y definiciones operativas poco trazables." `
                -Problem "La dispersion de configuracion dificulta despliegues consistentes, trazabilidad y manejo seguro de secretos." `
                -Scope "Identificar parametros, secretos y convenciones actuales para proponer el modelo objetivo." `
                -AcceptanceCriteria @(
                    "Se inventarian parametros y secretos relevantes por proceso.",
                    "Existe un esquema objetivo para configuracion y versionado.",
                    "Se definen lineamientos para separar configuracion, secretos y defaults."
                ) `
                -Deliverables @(
                    "Inventario de parametros y secretos.",
                    "Diseno objetivo de configuracion centralizada.",
                    "Guia de versionado y promocion por ambiente."
                ) `
                -Risks @(
                    "Puede haber secretos embebidos dificiles de detectar.",
                    "La migracion de configuracion puede romper compatibilidad con procesos legacy."
                )
        }
        @{
            Title    = "[EPIC] Scheduling y ejecucion"
            Priority = "P0"
            WorkType = "Epic"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody `
                -Objective "Definir el modelo objetivo de scheduling, ejecucion, reintentos y control operativo." `
                -CurrentContext "Los disparadores actuales pueden depender de Task Scheduler, servicios Windows y acciones manuales." `
                -Problem "Sin un modelo explicito de scheduling y ejecucion no se puede garantizar confiabilidad ni control de concurrencia." `
                -Scope "Mapear triggers actuales y definir el patron objetivo de orquestacion." `
                -AcceptanceCriteria @(
                    "Se documentan triggers, ventanas, dependencias y SLAs por proceso.",
                    "Se define un patron objetivo de ejecucion, reintentos y locking.",
                    "Se identifican excepciones que requieren tratamiento especial."
                ) `
                -Deliverables @(
                    "Mapa de scheduling actual.",
                    "Diseno objetivo de ejecucion y reintentos.",
                    "Lista de excepciones operativas."
                ) `
                -Risks @(
                    "Algunos procesos pueden depender de horarios rigidos o recursos exclusivos.",
                    "Reintentos mal definidos pueden generar duplicados."
                )
        }
        @{
            Title    = "[EPIC] Observabilidad minima"
            Priority = "P1"
            WorkType = "Epic"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody `
                -Objective "Definir e implementar un baseline de observabilidad para la migracion." `
                -CurrentContext "La cobertura de logs, metricas, trazabilidad y alertamiento puede ser inconsistente." `
                -Problem "La falta de observabilidad eleva el MTTR y dificulta validar migraciones." `
                -Scope "Establecer el estandar minimo de logs, metricas, health checks y alertas." `
                -AcceptanceCriteria @(
                    "Existe un estandar minimo de logging y correlacion.",
                    "Se define un set base de metricas y health checks.",
                    "Se acuerdan alertas minimas para procesos criticos."
                ) `
                -Deliverables @(
                    "Estandar minimo de observabilidad.",
                    "Checklist de implementacion por proceso.",
                    "Lista inicial de alertas y dashboards."
                ) `
                -Risks @(
                    "Exceso de telemetria puede encarecer la solucion.",
                    "Cobertura parcial puede dar una falsa sensacion de control."
                )
        }
        @{
            Title    = "[EPIC] Plan de migracion por oleadas"
            Priority = "P1"
            WorkType = "Epic"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody `
                -Objective "Disenar un plan de migracion incremental por oleadas que reduzca riesgo operativo." `
                -CurrentContext "La modernizacion involucra un volumen alto de procesos con criticidad y complejidad distintas." `
                -Problem "Migrar sin segmentacion ni criterios claros puede concentrar demasiado riesgo." `
                -Scope "Definir oleadas, criterios de entrada y salida, estrategia de pruebas y rollback." `
                -AcceptanceCriteria @(
                    "Se segmentan procesos en oleadas con criterios explicitos.",
                    "Cada oleada define precondiciones, pruebas y rollback.",
                    "Existe un roadmap priorizado con supuestos y dependencias."
                ) `
                -Deliverables @(
                    "Roadmap de oleadas.",
                    "Criterios de go/no-go por oleada.",
                    "Plan base de pruebas y rollback."
                ) `
                -Risks @(
                    "Dependencias ocultas pueden romper la segmentacion.",
                    "La capacidad del equipo puede variar entre oleadas."
                )
        }
    )

    $tasks = @(
        @{
            Title    = "[TASK] Levantar catalogo base de procesos y metadata operativa"
            Priority = "P0"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Consolidar una primera version del catalogo de procesos con metadata minima." -CurrentContext "La informacion esta dispersa entre scripts, tareas programadas y conocimiento del equipo." -Problem "No existe una base unica para saber que corre, cuando corre y con que dependencias." -Scope "Extraer procesos conocidos, normalizar nombres y registrar metadata minima." -AcceptanceCriteria @("Cada proceso tiene un registro base en el catalogo.", "Se captura frecuencia, owner, entradas y salidas conocidas.") -Deliverables @("Catalogo base de procesos.", "Checklist de metadata minima.") -Risks @("Puede haber diferencias entre lo configurado y lo que realmente se ejecuta.")
        }
        @{
            Title    = "[TASK] Clasificar procesos por criticidad, dependencia y frecuencia"
            Priority = "P1"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Segmentar los procesos inventariados para apoyar priorizacion y oleadas." -CurrentContext "Tras el levantamiento inicial falta traducir el catalogo a una vista de riesgo y esfuerzo." -Problem "Sin clasificacion, todos los procesos compiten por prioridad sin contexto." -Scope "Definir criterios y aplicarlos al inventario base." -AcceptanceCriteria @("Cada proceso tiene nivel de criticidad y frecuencia.", "Se documentan dependencias principales y riesgos.") -Deliverables @("Matriz de criticidad y dependencia.", "Criterios de clasificacion documentados.") -Risks @("La criticidad puede variar por ambiente o ventana operativa.")
        }
        @{
            Title    = "[TASK] Documentar drivers y restricciones para la plataforma objetivo"
            Priority = "P0"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Capturar drivers de negocio, operacion, seguridad y costo para evaluar la plataforma objetivo." -CurrentContext "La discusion de plataforma necesita criterios claros y compartidos." -Problem "Sin drivers explicitos, la decision se vuelve subjetiva y dificil de defender." -Scope "Recopilar restricciones, requisitos no funcionales y decisiones ya tomadas." -AcceptanceCriteria @("Existe una lista priorizada de drivers y restricciones.", "Los supuestos quedan registrados y reutilizables en el ADR.") -Deliverables @("Documento de drivers y restricciones.", "Lista de supuestos y preguntas abiertas.") -Risks @("Algunos drivers pueden ser implicitos y no aparecer en entrevistas iniciales.")
        }
        @{
            Title    = "[TASK] Comparar opciones de plataforma y redactar ADR inicial"
            Priority = "P0"
            WorkType = "ADR"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Comparar alternativas viables y producir un ADR inicial para decision." -CurrentContext "Con los drivers definidos se necesita una decision formal y trazable." -Problem "Sin comparativa estructurada y ADR, la plataforma objetivo puede cambiar sin control." -Scope "Evaluar opciones, trade-offs y recomendacion final." -AcceptanceCriteria @("Se comparan alternativas con criterios comunes.", "El ADR describe decision, contexto, consecuencias y riesgos.") -Deliverables @("Matriz comparativa.", "ADR inicial de plataforma objetivo.") -Risks @("La disponibilidad de capacidades puede cambiar durante la evaluacion.")
        }
        @{
            Title    = "[TASK] Inventariar parametros y secretos por proceso"
            Priority = "P1"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Identificar configuraciones y secretos necesarios para operar cada proceso." -CurrentContext "La configuracion actual puede estar en rutas locales, scripts o programadores." -Problem "No se puede centralizar lo que no esta identificado ni clasificado." -Scope "Levantar parametros, secretos, origen y sensibilidad." -AcceptanceCriteria @("Cada proceso tiene lista preliminar de parametros y secretos.", "Se distingue configuracion mutable de valores fijos.") -Deliverables @("Inventario de configuracion.", "Inventario de secretos.") -Risks @("Puede haber secretos embebidos o sin owner claro.")
        }
        @{
            Title    = "[TASK] Disenar esquema y versionado de configuracion compartida"
            Priority = "P1"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Definir el modelo objetivo para estructurar, versionar y promover configuracion entre ambientes." -CurrentContext "Tras inventariar configuracion se necesita una convencion comun para operarla." -Problem "Sin esquema ni versionado, la centralizacion puede replicar el caos actual." -Scope "Disenar llaves, jerarquia, ownership y reglas de promocion." -AcceptanceCriteria @("Existe un esquema objetivo documentado.", "Se definen reglas de versionado y promocion por ambiente.") -Deliverables @("Diseno de esquema de configuracion.", "Guia de versionado y promocion.") -Risks @("Un modelo demasiado rigido puede dificultar adopcion incremental.")
        }
        @{
            Title    = "[TASK] Mapear triggers actuales y ventanas operativas"
            Priority = "P0"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Task Scheduler"
            Body     = New-IssueBody -Objective "Documentar como se disparan hoy los procesos y que restricciones operativas tienen." -CurrentContext "Existen ejecuciones por scheduler, servicios y acciones manuales." -Problem "Sin mapa de triggers y ventanas, cualquier cambio de plataforma puede romper operaciones." -Scope "Registrar disparadores, horarios, dependencias y excepciones." -AcceptanceCriteria @("Cada proceso tiene trigger actual documentado.", "Se identifican ventanas y restricciones.") -Deliverables @("Mapa de triggers actuales.", "Registro de ventanas operativas y excepciones.") -Risks @("Puede haber triggers heredados o duplicados no detectados.")
        }
        @{
            Title    = "[TASK] Definir patron objetivo de ejecucion, reintentos y locks"
            Priority = "P0"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Acordar el comportamiento objetivo de ejecucion y control operativo para la plataforma modernizada." -CurrentContext "El comportamiento actual puede variar entre procesos y tecnologias." -Problem "Reintentos y concurrencia mal definidos generan duplicados o reprocesos." -Scope "Definir politicas de ejecucion, reintentos, timeouts, locks y cancelacion." -AcceptanceCriteria @("Existe una propuesta base de ejecucion y reintentos.", "Se documentan reglas de locking y exclusividad.") -Deliverables @("Patron objetivo de ejecucion.", "Politicas de reintentos y locking.") -Risks @("No todos los procesos soportaran el mismo patron sin adaptaciones.")
        }
        @{
            Title    = "[TASK] Definir estandar minimo de logs, metricas y correlacion"
            Priority = "P1"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Establecer un baseline comun de observabilidad para los procesos modernizados." -CurrentContext "La senal operativa actual puede ser inconsistente o insuficiente." -Problem "Sin estandar minimo, cada proceso emitira telemetria distinta y dificil de usar." -Scope "Definir convenciones de logs, metricas clave y correlacion." -AcceptanceCriteria @("Existe una convencion de logging minima.", "Se define un set base de metricas por ejecucion.") -Deliverables @("Estandar minimo de observabilidad.", "Checklist de adopcion por proceso.") -Risks @("La sobreinstrumentacion puede elevar costo sin mejorar diagnostico.")
        }
        @{
            Title    = "[TASK] Implementar checklist de health checks y alertas minimas"
            Priority = "P1"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Definir la cobertura minima de health checks y alertamiento para operacion inicial." -CurrentContext "No todos los procesos cuentan con verificacion activa de salud o alertamiento util." -Problem "Sin health checks ni alertas minimas, fallas silenciosas pueden pasar desapercibidas." -Scope "Identificar senales minimas y acordar criterios de alerta." -AcceptanceCriteria @("Existe una lista base de health checks por tipo de proceso.", "Se documentan alertas minimas y su severidad.") -Deliverables @("Checklist de health checks.", "Catalogo inicial de alertas.") -Risks @("Alertas mal calibradas pueden generar ruido operativo.")
        }
        @{
            Title    = "[TASK] Segmentar procesos por oleadas y criterios de corte"
            Priority = "P1"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Agrupar procesos en oleadas ejecutables y con riesgo controlado." -CurrentContext "El volumen de procesos obliga a dividir la migracion en fases manejables." -Problem "Sin oleadas y criterios de corte, la ejecucion del plan sera dificil de gobernar." -Scope "Definir grupos, dependencias, precondiciones y objetivos por oleada." -AcceptanceCriteria @("Cada proceso pertenece a una oleada preliminar.", "Las oleadas tienen criterios de entrada y salida.") -Deliverables @("Matriz de oleadas.", "Criterios de corte por oleada.") -Risks @("Dependencias ocultas pueden forzar resegmentacion.")
        }
        @{
            Title    = "[TASK] Definir plan de pruebas, rollback y salida a produccion"
            Priority = "P1"
            WorkType = "Task"
            Tech     = "Mixed"
            RunMode  = "Unknown"
            Body     = New-IssueBody -Objective "Establecer el marco minimo de pruebas y rollback para ejecutar oleadas con seguridad." -CurrentContext "Cada oleada necesitara controles claros antes, durante y despues de salir a produccion." -Problem "Sin plan de pruebas y rollback, la migracion aumenta su riesgo operativo." -Scope "Definir tipos de prueba, criterios de go/no-go y estrategia de reversa." -AcceptanceCriteria @("Existe un plan base de pruebas por oleada.", "Se documentan criterios de go/no-go y rollback.") -Deliverables @("Plan base de pruebas.", "Plantilla de rollback y salida a produccion.") -Risks @("Rollback incompleto puede dejar sistemas en estado mixto.")
        }
    )

    return @($epics + $tasks)
}

$repoNameWithOwner = "$Owner/$PrimaryRepo"

Test-GhAuthentication

$ownerNode = Get-OwnerNode -Login $Owner
$project = Get-OrCreateProject -OwnerLogin $ownerNode.Login -OwnerId $ownerNode.Id -Title $ProjectTitle

$desiredFields = @(
    @{ Name = "Repo Scope"; Options = @("orquestator-demon", "observabilidad-vso") }
    @{ Name = "Priority"; Options = @("P0", "P1", "P2", "P3") }
    @{ Name = "Work Type"; Options = @("Epic", "Task", "Spike", "ADR") }
    @{ Name = "Tech"; Options = @("PowerShell", "Java", "Python", "C#", "Mixed") }
    @{ Name = "Run Mode"; Options = @("Task Scheduler", "Windows Service", "Manual", "Unknown") }
)

foreach ($field in $desiredFields) {
    Ensure-SingleSelectField -OwnerLogin $Owner -ProjectNumber $project.Number -FieldName $field.Name -Options $field.Options
}

$issueDefinitions = Build-IssueDefinitions
$projectLookup = Get-SingleSelectFieldLookup -OwnerLogin $Owner -ProjectNumber $project.Number

foreach ($definition in $issueDefinitions) {
    $issue = Get-OrCreateIssue -Repository $repoNameWithOwner -Definition $definition
    $projectItem = Ensure-IssueInProject -OwnerLogin $Owner -ProjectNumber $project.Number -IssueUrl $issue.url -ProjectLookup $projectLookup
    $projectLookup = $projectItem.Lookup

    Set-SingleSelectFieldValue -ProjectId $projectItem.ProjectId -ItemId $projectItem.ItemId -FieldLookup $projectItem.Fields -FieldName "Repo Scope" -OptionName $PrimaryRepo
    Set-SingleSelectFieldValue -ProjectId $projectItem.ProjectId -ItemId $projectItem.ItemId -FieldLookup $projectItem.Fields -FieldName "Priority" -OptionName $definition.Priority
    Set-SingleSelectFieldValue -ProjectId $projectItem.ProjectId -ItemId $projectItem.ItemId -FieldLookup $projectItem.Fields -FieldName "Work Type" -OptionName $definition.WorkType
    Set-SingleSelectFieldValue -ProjectId $projectItem.ProjectId -ItemId $projectItem.ItemId -FieldLookup $projectItem.Fields -FieldName "Tech" -OptionName $definition.Tech
    Set-SingleSelectFieldValue -ProjectId $projectItem.ProjectId -ItemId $projectItem.ItemId -FieldLookup $projectItem.Fields -FieldName "Run Mode" -OptionName $definition.RunMode
}

$finalSnapshot = Get-SingleSelectFieldLookup -OwnerLogin $Owner -ProjectNumber $project.Number

Write-Host ""
Write-Host "Project ready: $($project.Title) (#$($project.Number))" -ForegroundColor Green
Write-Host "URL: $($finalSnapshot.Url)"
Write-Host "Repository for initial issues: $repoNameWithOwner"
Write-Host "Repo tracking uses the custom field 'Repo Scope' because Projects v2 rejects 'Repo' as a reserved custom field name."
Write-Host ""
Write-Host "Manual steps still recommended in the GitHub UI:" -ForegroundColor Yellow
Write-Host "1. Open the project URL."
Write-Host "2. Create or adjust the saved views you want (table/board), since gh CLI does not manage saved views or visual layout reliably."
Write-Host "3. Reorder fields or columns visually if you want a specific presentation."
