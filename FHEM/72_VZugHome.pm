#
#  72_VZugHome.pm
#
# VZug
#                                                            

package main;

# Laden evtl. abhängiger Perl- bzw. FHEM-Hilfsmodule
use HttpUtils;
use JSON;

use Net::Ping;

#####################################################################################################################
# Helper routine for flattening a hash structure
#  https://gist.github.com/danieljoos/08cb27106193e1210e67
sub VZugHome_flatten {
    my ($h, $r, $p) = @_; $r = {} if not $r; $p = '' if not $p;
    my $typed; $typed = sub {
        my ($v, $p) = @_;
        if (ref $v eq 'HASH') { VZugHome_flatten($v, $r, $p.'.'); }
        elsif (ref $v eq 'ARRAY') { foreach(0..$#$v) { $typed->(@$v[$_], $p.'['.$_.']'); } }
        else { $r->{$p} = $v; }
    };
    foreach (keys %$h) { $typed->($$h{$_}, $p.$_); };
    return $r;
}

sub VZugHome_CallingDeviceResult
{
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $hVzParamVal = $param->{hVzParamVal};

    my $sDevName = $hash->{NAME};
    my $sDevType = $hash->{TYPE};
    my $sDevIp = $hash->{DevIP};
    my $sDevTimeout = $hash->{DevTimeout};
    my $sLogHeader = "VZugHome_CallingDeviceResult $sDevName:";

    undef %hResCalling;

#if ($param) { my $sTmp = decode_json(%$param); }
    Log3 $sDevName, 0, "$sLogHeader: $sTmp: give me back: data: $data / error: $err";

    if (($err eq "") && ($data) && ($data ne 'UNDEF') && (substr($data,0,20) ne '{"error":{"code":500') && (substr($data,0,20) ne '{"error":{"code":400'))
    {
# Get related result type
        $sVzResType = %$hVzParamVal{"sResType"};
        $sVzResFunc = %$hVzParamVal{"sResFunc"};
        Log3 $sDevName, 0, "$sLogHeader result should be $sVzResType / function is $sVzResFunc";

        if ($sVzResFunc eq "Readings")
        {
            readingsBeginUpdate($hash);
            Log3 $sDevName, 0, "$sLogHeader readingsBeginUpdate called";
        }

# Check if result type is JSON and flat it
        if ($sVzResType eq "json")
        {
            Log3 $sDevName, 0, "$sLogHeader result is json";
            $oVzDecJson = decode_json($data);
            if (ref $oVzDecJson eq 'HASH')
            {
                my $oVzFlatJson = VZugHome_flatten($oVzDecJson);
                foreach my $sVzResJsonKey (keys %$oVzFlatJson)
                {
                    my $sVzResJsonVal = %$oVzFlatJson{$sVzResJsonKey};
                    my $sVzIntFldName = %$hVzParamVal{"sIntName"} . "." . $sVzResJsonKey;
                    if ($sVzResJsonVal eq "")
                    { $sVzResJsonVal = "-"; } 
                    else
                    {
# Remove non-ASCII characters and white spaces
                        $sVzResJsonVal =~ s/[^[:ascii:]]//g; 
                        $sVzResJsonVal =~ s/^\s+|\s+$//g
                    }

                    if ($sVzResFunc eq "Internals")
                    {
                        $hash->{$sVzIntFldName} = $sVzResJsonVal;
                    }
                    elsif ($sVzResFunc eq "Readings")
                    {
                        Log3 $sDevName, 0, "$sLogHeader Readings: $sVzIntFldName / $sVzResJsonVal";
                        readingsBulkUpdateIfChanged($hash, $sVzIntFldName, $sVzResJsonVal);
                    }
                    elsif ($sVzResFunc eq "IntCmd")
                    {
                        Log3 $sDevName, 0, "$sLogHeader IntCmd: $sVzIntFldName / $sVzResJsonVal";
                    }
                    $hResCalling{$sVzIntFldName} = $sVzResJsonVal;
                    Log3 $sDevName, 0, "$sLogHeader Result: $sVzIntFldName / $sVzResJsonVal";
                }
            }
            else
            {
                my $sResType = ref $oVzDecJson;
                Log3 $sDevName, 0, "$sLogHeader hash result expected, but it is $sResType";
            }
        }
        else
        {
            Log3 $sDevName, 0, "$sLogHeader result is text";
            if ($data eq "") { $data = "-"; }
            if ($sVzResFunc eq "Internals")
            {
                $hash->{%$hVzParamVal{"sIntName"}} = $data;
            }
            elsif ($sVzResFunc eq "Readings")
            {
                Log3 $sDevName, 0, "$sLogHeader Readings: $sVzIntFldName / $sVzResJsonVal";
                readingsBulkUpdateIfChanged($hash, %$hVzParamVal{"sIntName"}, $data);
            }
            else
            {
                Log3 $sDevName, 0, "$sLogHeader IntCmd: $sVzIntFldName / $sVzResJsonVal";
            }
            $hResCalling{%$hVzParamVal{"sIntName"}} = $data;
        }

        if ($sVzResFunc eq "Readings") { readingsEndUpdate($hash, 0); }
        $hash->{STATE} = 'active';
    }
    else
    {
        Log3 $sDevName, 0, "$sLogHeader: $sVzDevUrl Error or timeout";
    }

#    return %hResCalling;
}

#####################################################################################################################
sub VZugHome_GetReadingUpdates
{
    my ($VzParamUpd) = @_;
    my $hash = $VzParamUpd->{hash};
    my $sCalltype = $VzParamUpd->{calltype};
    my $sDevName = $hash->{NAME};
    my $sDevType = $hash->{TYPE};
    my $sDevIp = $hash->{DevIP};
    my $sDevTimeout = $hash->{DevTimeout};
    my $sDevFhemState = $hash->{STATE};
    my $sLogHeader = "VZugHome_GetReadingUpdates $sDevName:";
    my $iInterval = $attr{$sDevName}{Interval};

    my $sUsername = urlEncode($hash->{DevUsername});
    my $sPassword = urlEncode($hash->{DevPassword});

    Log3 $sDevName, 0, "$sLogHeader is called [$sCalltype]";
    $oVzCheckHostAlive = Net::Ping->new( );

    if ($oVzCheckHostAlive->ping($sDevIp,2))
    {
        Log3 $sDevName, 0, "$sLogHeader Device is up $sDevIp [ping]";

        if ($sCalltype eq "internals")
        {
            Log3 $sDevName, 0, "$sLogHeader sub internals";
            %hVzParamListUpd = (
                "ai getDeviceStatus" => { sResFunc => 'Readings', sResType => 'json', sIntName => 'VzAiDeviceStatus' },
                "ai getAPIVersion" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzAiApiVersion' },
                "ai isAIFirmwareAvailable" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzAiAiFwAvailable' },
                "ai isHHGFirmwareAvailable" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzAiHhFwAvailable' },
                "hh getAPIVersion" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzHhApiVersion' },
                "hh getDeviceName" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhDeviceName' },
                "hh getFWVersion" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzHhFwVersion' },
                "hh getLanguage" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhLanguage' },
                "hh getMachineType" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhMachineType' },
                "hh getModel" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhModel' },
                "hh getModelDescription" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhModelDescription' },
                "hh getSupportedLanguages" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzHhSupportedLanguages' },
                "hh getTime" => { sResFunc => 'Readings', sResType => 'text', sIntName => 'VzHhTime' },
            );
            $iInterval = 60;
        }

        if ($sCalltype eq "readings")
        {
# Define V-Zug Home readings
            Log3 $sDevName, 0, "$sLogHeader sub readings";
            %hVzParamListUpd = (
                "ai getDeviceStatus" => { sResFunc => 'Readings', sResType => 'json', sIntName => 'VzAiDeviceStatus' },
                "hh getTime" => { sResFunc => 'Readings', sResType => 'text', sIntName => 'VzHhTime' },
                "hh getCategories" => { sResFunc => 'IntCmd', sResType => 'text', sIntName => 'VzHhGetCategories' },
            );
            if ($iInterval < 10) { $iInterval = 15; }
        }


#if ($hVzParamListUpd) { my $sTmp = decode_json($hVzParamListUpd); }
#        Log3 $sDevName, 0, "$sLogHeader before while $sTmp";
        Log3 $sDevName, 0, "$sLogHeader Start While";
        while ((my $sVzParamKey, my $hVzParamVal) = each %hVzParamListUpd)
        {
            Log3 $sDevName, 0, "$sLogHeader calling VZugHome_CallingDevice // $sVzParamKey </> $hVzParamVal ...";
#            %hRes = VZugHome_CallingDevice ($hash, $sVzParamKey, $hVzParamVal);

            my @hReq = split / /, $sVzParamKey;
            my $sReqType = $hReq[0];
            my $sReqCmd = $hReq[1];
            my $sVzDevUrl = "http://$sDevIp/$sReqType?command=$sReqCmd";

# Prepare parameter for HTTP get
            my $param = {
                            url         => $sVzDevUrl,
                            timeout     => $sDevTimeout,
                            method      => "GET",
                            noshutdown  => 1,
                            user        => $sUsername,
                            pwd         => $sPassword,
                            header      => "User-Agent: fhem_VZugHome/0.0.1\r\nAccept-Language: en",
                            hVzParamVal => $hVzParamVal,
                            hash        => $hash,
                            callback    => \&VZugHome_CallingDeviceResult
                        };
            HttpUtils_NonblockingGet($param);
        }
        Log3 $sDevName, 0, "$sLogHeader End While";
        $hash->{STATE} = 'active';
    }
    else
    {
        $hash->{STATE} = 'down';
        Log3 $sDevName, 0, "$sLogHeader Device is down $sDevIp [ping] retry after 120 seconds";
        $iInterval = 120;
    }
    $oVzCheckHostAlive->close;

# Set new timer for next update
    my $VzParamUpd = {
        hash     => $hash,
        calltype => $sCalltype
    };
    InternalTimer(gettimeofday()+$iInterval, "VZugHome_GetReadingUpdates", $VzParamUpd);

    return undef;
}

#####################################################################################################################
sub VZugHome_Initialize
{
    my ($hash) = @_;
    Log3 $hash, 5, "VZugHome_Initialize: Start";

    $hash->{DefFn}	= "VZugHome_Define";
    $hash->{UndefFn}	= "VZugHome_Undef";
#$hash->{StateFn}    = "VZugHome_State";
#$hash->{GetFn}	= "VZugHome_Get";
#$hash->{RenameFn}   = "VZugHome_Rename";
#$hash->{SetFn}      = "VZugHome_Set";
    $hash->{AttrFn}	= "VZugHome_Attr";
    $hash->{AttrList}	= "Interval " . $readingFnAttributes;

#    return undef;
}

#####################################################################################################################
sub VZugHome_Define
{
    my ( $hash, $def ) = @_;
    my @hDefParms = split( "[ \t][ \t]*", $def );

    return "Usage: define <MyDeviceName> VZugHome <appliance IP or DNS Name> <Timeout> <username> <passwword>" if(@hDefParms < 4);
    my $sDevName = $hDefParms[0];
    my $sDevType = $hDefParms[1];
    my $sDevIp = $hDefParms[2];
    my $sDevTimeout = $hDefParms[3];
    my $sLogHeader = "VZugHome_Define $sDevName:";

    $hash->{STATE} = 'Initializing';
    $hash->{NAME} = $sDevName;
    $hash->{TYPE} = $sDevType;
    $hash->{DevIP} = $sDevIp;
    $hash->{DevTimeout} = $sDevTimeout;

# Optional username and password for device access
    if ($hDefParms[5] and $hDefParms[6])
    {
        my $sVzUsername = $hDefParms[5];
        my $sVzPassword = $hDefParms[6];
        $hash->{DevUsername} = $sVzUsername;
        $hash->{DevPassword} = $sVzPassword;
    }

    Log3 $sDevName, 0, "$sLogHeader on $sDevIp called";

    $oVzCheckHostAlive = Net::Ping->new( );
#        or die "Can't create new ping object: $!\n";
    if ($oVzCheckHostAlive->ping($sDevIp,2))
    {
        Log3 $sDevName, 0, "$sLogHeader Device is up $sDevIp [ping]";
        my %hVzParamVal;
# Define V-Zug Home requests
        my %hVzParamListDefine = (
            "ai getDeviceStatus" => { sResFunc => 'Readings', sResType => 'json', sIntName => 'VzAiDeviceStatus' },
            "ai getAPIVersion" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzAiApiVersion' },
            "ai isAIFirmwareAvailable" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzAiAiFwAvailable' },
            "ai isHHGFirmwareAvailable" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzAiHhFwAvailable' },
            "hh getAPIVersion" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzHhApiVersion' },
            "hh getDeviceName" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhDeviceName' },
            "hh getFWVersion" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzHhFwVersion' },
            "hh getLanguage" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhLanguage' },
            "hh getMachineType" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhMachineType' },
            "hh getModel" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhModel' },
            "hh getModelDescription" => { sResFunc => 'Internals', sResType => 'text', sIntName => 'VzHhModelDescription' },
            "hh getSupportedLanguages" => { sResFunc => 'Internals', sResType => 'json', sIntName => 'VzHhSupportedLanguages' },
            "hh getTime" => { sResFunc => 'Readings', sResType => 'text', sIntName => 'VzHhTime' },
        );

        while ((my $sVzParamKey, my $hVzParamVal) = each %hVzParamListDefine)
        {
            my @hReq = split / /, $sVzParamKey;
            my $sReqType = $hReq[0];
            my $sReqCmd = $hReq[1];
            my $sVzDevUrl = "http://$sDevIp/$sReqType?command=$sReqCmd";

# Prepare parameter for HTTP get
            my $param = {
                            url         => $sVzDevUrl,
                            timeout     => $sDevTimeout,
                            method      => "GET",
                            noshutdown  => 1,
                            user        => $sUsername,
                            pwd         => $sPassword,
                            header      => "User-Agent: fhem_VZugHome/0.0.1\r\nAccept-Language: en",
                            hVzParamVal => $hVzParamVal,
                            hash        => $hash,
                            callback    => \&VZugHome_CallingDeviceResult
                        };
            HttpUtils_NonblockingGet($param);
        }
        $hash->{STATE} = 'initialized';
    }
    else
    {
        $hash->{STATE} = 'down';
        Log3 $sDevName, 0, "$sLogHeader Device is down $sDevIp [ping]";
    }
    $oVzCheckHostAlive->close;
  
#Set timer for internal update
    my $VzParamUpd = {
        hash     => $hash,
        calltype => "internals"
    };
    InternalTimer(gettimeofday()+5, "VZugHome_GetReadingUpdates", $VzParamUpd);

#Set timer for readings update
    my $VzParamUpd = {
        hash     => $hash,
        calltype => "readings"
    };
    InternalTimer(gettimeofday()+10, "VZugHome_GetReadingUpdates", $VzParamUpd);

    return undef;
}

#####################################################################################################################
sub VZugHome_Attr
{
    my ($cmd,$name,$attr_name,$attr_value) = @_;
    if($cmd eq "set")
    {
        if($attr_name eq "Interval")
        {
            if (($attr_value < 10) or ($attr_value > 300))
            {
                my $err = "Invalid time $attr_value to $attr_name. Must be between 10 and 300.";
                return $err;
            }
        }
    }
    return undef;
}

#####################################################################################################################
sub VZugHome_Undef
{
    my ($hash) = @_;
    my $sDevName = $hash->{NAME};
    my $sDevIp = $hash->{DevIP};
    
    Log3 $sDevName, 0, "VZugHome_Undef $sDevName on $sDevIp called";

    RemoveInternalTimer($hash);

    return undef;
}

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;


# Beginn der Commandref

=pod
=item device
=item summary Read status of V-Zug appliances with integrated V-Zug Home module
=item summary_DE Liest den Status von V-Zug Haushaltsgeräten mit integrierter V-Zug Home Schnittstelle

=begin html

<a name="VZugHome"></a>
<h3>V-Zug-Home</h3>

<a name="VZugHomedefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;MyDeviceName&gt; VZugHome &lt;appliance IP or DNS Name&gt; &lt;timeout&gt; [&lt;username&gt; &lt;password&gt;]</code>
    <br><br>
    Defines a V-Zug-Home appliance at the given host address and you are able to get the status of the defined appliance.
    <ul>
        <li><code>Timeout</code> in seconds, how long FHEM should be wait for the answer.</li>
        <li>For <code>username</code> and <code>password</code> protected appliances, you can give the username and password as optional parameter.</li>
    </ul>
    <br>
    Example:
    <ul>
      <code>define EmmasBackofen VZugHome 192.168.0.55 3</code><br>
      <code>define EmmasBackofen VZugHome 192.168.0.55 3 myUser myPass</code><br>
    </ul>
    <br>
  </ul>
  <br><br>

<a name="VZugHomeattr"></a>
  <b>Attributes</b>
  <ul>
    <code>attr &lt;MyDeviceName&gt; Interval &lt;Interval&gt;</code>
    <br><br>
    <ul>
        <li><code>Interval</code> in seconds, time where the readings should be updated (10 - 300).</li>
    </ul>
    <br>
    Example:
    <ul>
      <code>attr EmmasBackofen Interval 15</code><br>
    </ul>
    <br>
  </ul>
  <br><br>

<a name="VZugHomereadings"></a>
  <b>Readings</b>
  <ul>
    Readings are dynamic generated from the specified V-Zug appliance.
    <br><br>
    Example for a Adora SL Waschingmachine:
        <table class="block wide readings">
            <tr class="odd">
                <td>VzAiDeviceStatus.DeviceName</td>
                <td>Adora SL</td>
            </tr>
            <tr class="even">
                <td>VzAiDeviceStatus.Inactive</td>
                <td>false</td>
            </tr>
            <tr class="odd">
                <td>VzAiDeviceStatus.Program</td>
                <td>-</td>
            </tr>
            <tr class="even">
                <td>VzAiDeviceStatus.ProgramEnd.End</td>
                <td>-</td>
            </tr>
            <tr class="odd">
                <td>VzAiDeviceStatus.ProgramEnd.EndType</td>
                <td>0</td>
            </tr>
            <tr class="even">
                <td>VzAiDeviceStatus.Serial</td>
                <td>12345 123456</td>
            </tr>
            <tr class="odd">
                <td>VzAiDeviceStatus.Status</td>
                <td>-</td>
            </tr>
            <tr class="even">
                <td>VzHhTime</td>
                <td>2000-01-01T00:00:15</td>
            </tr>
        </table>
    <br>
    <br>
  </ul>
  <br><br>


 Englische Commandref in HTML
=end html

=begin html_DE
 Deutsche Commandref in HTML
=end html

# Ende der Commandref
=cut
