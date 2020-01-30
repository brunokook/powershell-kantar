﻿$Site = Read-Host 'Qual a url quer navegar?';
$currentTime = $(get-date).ToString("yyyyMMddHHmmss")  
$logFilePath = ".\log-" + $currentTime + ".docx"  
# Fields that has to be retrieved  
$Global:selectProperties = @("Old");

#While pra validar se url é vazia
while (!$Site) {
    $Site = Read-Host 'Qual a url quer navegar?';  
}

function loadLists{
    param([string]$ListDe, [string]$ListPara)
    #Pegando as listas

     $sourceList = Get-PnPList -Identity $ListDe;
     $targetList = Get-PnPList -Identity $ListPara;
        if($sourceList -eq $null -or $targetList -eq $null){
            return "Valor inválido";
        } 
        else{

        [array]$sourceItems = Get-PnPListItem -List $ListDe;
        #Array de colunas source e target
        $sourceFields = $sourceList.Fields
        $targetFields = $targetList.Fields
        #Carregando o contexto da lista
        $sourceList.Context.Load($sourceFields);
        $sourceList.Context.ExecuteQuery();
        $targetList.Context.Load($targetFields);
        $targetList.Context.ExecuteQuery();
        #Listas de campos
        $listaEncontrados = @()
        $listaNaoEncontrados = @()
        #Para cada coluna nas colunas da source
        foreach ($Field in $sourceFields | Where-Object { $_.FromBaseType -eq $false }) {
            #No Array de colunas do target, procure onde o nome interno for igual ao nome interno da source e tenha sido criado por usuário
            $itemEncontrado = $targetFields | Where-Object { $Field.FromBaseType -eq $false -and $_.FromBaseType -eq $false };
            $itemEncontrado = $targetFields | Where-Object { $_.InternalName -in $Field.InternalName }
            if ($itemEncontrado -ne $Null) {
                $listaEncontrados += $itemEncontrado[0].InternalName
            } 
            else {
                $listaNaoEncontrados += $Field.InternalName
            }
        }
        #No array de items da source, para cada item, criar um json vazio, e adicionando os campos
        foreach ($item in $sourceItems) {
            $jsonBase = @{"Title" = $item["Title"]; "Modified" = $item["Modified"]; "Created" = $item["Created"]; }
            #Para cada campo na lista de campos encontrados, adicione em um json
            $identifyTitle = Get-PnPListItem -List $ListPara -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($item["Title"])</Value></Eq></Where></Query></View>";
            foreach ($campo in $listaEncontrados) {
                $jsonBase.Add($campo, $item[$campo]);
            }
            if ($identifyTitle.Length -gt 0) {
                #Adicione cada item com os valores do json montado
                Set-PnPListItem -List $ListPara -Values $jsonBase -Identity $identifyTitle.Id;
            }
            else {
                Add-PnPListItem -List $ListPara -Values $jsonBase
            }
        }
        try {
            $outputFilePath = ".\results-" + $currentTime + ".csv";
            $hashTable = @();
            foreach ($campo in $listaNaoEncontrados) {  
                $obj = New-Object PSObject              
                $obj | Add-Member -MemberType NoteProperty -name "CamposNaoEncontrados" -value $campo;
                $obj | Add-Member -MemberType NoteProperty -name "NovosNomes" -value $null;
                $hashTable += $obj;  
                $obj = $null;  
            }
            $hashtable | Export-Csv $outputFilePath -NoTypeInformation  
        }
        catch [Exception] {  
            $ErrorMessage = $_.Exception.Message         
            Write-Host "Error: $ErrorMessage" -ForegroundColor Red          
        } 
        Stop-Transcript
        # criar lista de campos
        # criar lista de campos não encontrados
        # iteração para cada field do Source
        # Valida se o campo existe no target, usando um filtro
        # SE o campo existe
        # adiciona o nome interno do campo na lista de campos
        # SENAO
        # adiciona o nome interno do campo na lista de campos nao encontrados
        # iteração para cada item da lista de source
        # criar objeto json
        # iteração para cada campo da lista de campos encontrados
        # crair uma proprierdade no objeto json
        # rodar add-pnplistitem com o valor do json gerado
        }
}
function tryToConnect {
    Param ([string]$siteurl)
    try {
        Connect-PnPOnline -Url $siteurl;
        
        Start-Transcript -Path $logFilePath   

        #Definindo inputs
        $ListDe = Read-Host 'Qual lista deseja copiar?';
        $ListDe = "Lists/" + $ListDe;
        $ListPara = Read-Host 'Para qual lista deseja enviar?';
        $ListPara = "Lists/" + $ListPara;
        #Pegando as listas
        $res = loadLists -ListDe $ListDe -ListPara $ListPara;
        if ($res -eq "Valor inválido") {
            
            do {      
                Write-Host "Listas não encontradas, insira novamente!" -ForegroundColor Red
                $ListDe = Read-Host 'Qual lista deseja copiar?';
                $ListDe = "Lists/" + $ListDe;
                $ListPara = Read-Host 'Para qual lista deseja enviar?';
                $ListPara = "Lists/" + $ListPara;

                $res = loadLists -ListDe $ListDe -ListPara $ListPara;
            }
            while ($res -eq "Valor inválido") 
        };
    }
    catch [Exception] {  
        $ErrorMessage = $_.CategoryInfo.Reason; 
        return $ErrorMessage;
    }
}
$result = tryToConnect -siteurl $Site;
if ($result -eq "UriFormatException") {
    
    do {
        Write-Host "Url não encontrada!" -ForegroundColor Red      
        $retry = Read-Host 'Qual a url quer navegar?'; 
        $res = tryToConnect -siteurl $retry
    }
    while ($res -eq "UriFormatException") 
};

