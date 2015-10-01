invoke-item ..\ZumoDeploy.cmd

write "Updating config file..."

$webConfigFilePath = [System.IO.Path]::Combine( $PWD, "..\wwwroot\web.config" );

[System.Xml.XmlDocument]$doc = new-object System.Xml.XmlDocument;

$doc.Load($webConfigFilePath);

$root = $doc.get_DocumentElement();
$webServerElement = $root.SelectSingleNode("system.webServer");

write "Configuring httpErrors element"
if(!$httpErrorsElement)
{
    $httpErrorsElement = $webServerElement.AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'httpErrors', $null));
}

$errorModeAttr = $httpErrorsElement.Attributes.GetNamedItem('errorMode');
if(!$errorModeAttr)
{
    $errorModeAttr = $httpErrorsElement.Attributes.Append($doc.CreateAttribute('errorMode'));
}
$errorModeAttr.Value= 'DetailedLocalOnly';

$defaultResponseModeAttr = $httpErrorsElement.Attributes.GetNamedItem('defaultResponseMode');
if(!$defaultResponseModeAttr)
{
    $defaultResponseModeAttr = $httpErrorsElement.Attributes.Append($doc.CreateAttribute('defaultResponseMode'));
}
$defaultResponseModeAttr.Value= 'DetailedLocalOnly';

$errorFileFolder="errorpages";

$errorPath = [System.IO.Path]::Combine($PWD, "..\wwwroot\"+$errorFileFolder);

#remove the error child nodes and start fresh, makes the for loop a little simpler
$httpErrorsElement.RemoveAll();

#hash table containing error codes and the the filnames for each custom error page
$errCodes = @{400 = '400.html'; 403 = '403.html'; 500 = '500.html'};
foreach ($errCode in $errCodes.Keys)
{
    $errCodeElement = $httpErrorsElement.AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'Error', $null));
    $statusCodeAttr = $errCodeElement.Attributes.Append($doc.CreateAttribute('statusCode'));
    $statusCodeAttr.Value = $errCode;
    $pathAttr = $errCodeElement.Attributes.Append($doc.CreateAttribute('path'));
    $pathAttr.Value = [System.IO.Path]::Combine( $errorPath, $errCodes[$errCode]);
}

write "Copying Custom Error Files to wwwroot"
$fromFileLocation = [System.IO.Path]::Combine($PWD,$errorPath);

if(!Test-Path $errorPath)
{
    MD $errorPath;
}

Copy-Item -Path $fromFileLocation -Filter * -Destination $errorPath

write "Configuring server header removal"
$securityElement = $webServerElement.SelectSingleNode("security");

if (!$securityElement)
{
    $securityElement = $webServerElement.AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'security',$null));
}

$requestFilteringElement = $securityElement.SelectSingleNode("requestFiltering");

if (!$requestFilteringElement)
{
    $requestFilteringElement = $securityElement.AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'requestFiltering',$null));
}

$requestFilteringElement.SetAttribute('removeServerHeader',"true");

write "Configuring custom header removal"
$httpProtocolElement = $webServerElement.SelectSingleNode("httpProtocol");

if (!$httpProtocolElement)
{
    write "Creating httpProtocol element";
    $httpProtocolElement = $webServerElement.AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'httpProtocol',$null));
}

$customHeadersElement = $httpProtocolElement.SelectSingleNode("customHeaders");

if (!$customHeadersElement)
{
    write "Creating customHeaders element";
    $customHeadersElement = $httpProtocolElement.AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'customHeaders',$null));
}

foreach ($arg in $args)
{
    write "Configuring $arg header removal.";
    $headerElement = $customHeadersElement.SelectSingleNode("remove[@name='$arg']");
    if (!$headerElement)
    {
        $headerElement = $customHeadersElement.AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'remove',$null));
        $headerElement.SetAttribute('name',$arg);
    }
    else
    {
        write "Skipping header configuration for $arg, header removal is already setup."
    }
}


write "Creating x-zumo-version header rule"
$outboundRulesElement = $webServerElement.SelectSingleNode("rewrite/outboundRules");

if (!$outboundRulesElement)
{
    $outboundRulesElement = $webServerElement.SelectSingleNode("rewrite").AppendChild($doc.CreateNode([System.Xml.XmlNodeType]::Element,'outboundRules',$null));
}

$ruleName = "remove zumo header"
if (!$outboundRulesElement.SelectSingleNode("rule[@name='$rulename']"))
{
    $ruleFragment = $doc.CreateDocumentFragment();
    $ruleFragment.InnerXml = @"

    <rule name="$ruleName">
          <match serverVariable="RESPONSE_x-zumo-version" pattern=".*" />
          <conditions />
          <action type="Rewrite" value="" />
    </rule>

"@;

    $outboundRulesElement.AppendChild($ruleFragment);
}

$doc.Save([System.IO.Path]::Combine( $PWD, "..\wwwroot\web.config" ));

