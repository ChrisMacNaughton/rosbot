<?php

error_reporting(E_ALL);

define('INFRACODE', '/opt/rosbot/infracode');
require_once(INFRACODE . '/config.php');
require_once(INFRACODE . '/php/log.php');
require_once(INFRACODE . '/php/triad.php');
require_once(INFRACODE . '/php/gitlab.php');
require_once(INFRACODE . '/php/email.php');

# Set up logging.
$log = new \Monolog\Logger('rosbot-sendinvoice');
$formatter = new \Monolog\Formatter\LineFormatter("> %message%\n");
$handler = new \Monolog\Handler\ErrorLogHandler();
$handler->setFormatter($formatter);
$handler->setLevel(\Monolog\Logger::INFO);
$log->pushHandler($handler);
GlobalLog::$log = $log;

try
{
    # Check script input.
    $currentChannelID = $argv[1];
    if (!preg_match('/^[A-Za-z0-9_-]*$/', $currentChannelID))
    {
        $log->error('Parameters contain illegal character.');
        throw new Exception('input validation failed');
    }
    $alias = isset($argv[2]) ? trim($argv[2]) : '';
    if (!preg_match('/^[A-Za-z0-9_-]*$/', $alias))
    {
        $log->error('Parameters contain illegal character.');
        throw new Exception('input validation failed');
    }

    if ($alias != '') # An alias was given as part of the rosbot command.
    {
        # Only send invoice for 'pen' type projects;
        # assume that prefix if not given.
        if (explode('-', $alias, 2)[0] != Triad::PEN)
        {
            $alias = Triad::PEN . '-' . $alias;
        }

        # Look up project from given alias.
        try
        {
            $triad = Triad::fromAlias($alias);
        }
        catch (Exception $e)
        {
            $log->error('The alias ' . $alias . ' is not listed as a pentest project.');
            throw new Exception('unknown alias');
        }
    }
    # No alias was given as part of the rosbot command, so assume the pentest
    # corresponding to the current channel.
    else
    {
        try
        {
            $triad = Triad::fromRoomID($currentChannelID);
        }
        catch (Exception $e)
        {
            $log->error('The current channel is not listed as a pentest project channel.');
            throw new Exception('unknown channel');
        }
    }
    if ($triad->type != Triad::PEN)
    {
        $log->error('The current channel does not appear to be connected to a pentest.');
        throw new Exception('unsupported channel');
    }
    
    $log->info('Looking up invoice data for ' . $triad->name . '...');
    $gl = GlobalGitlabClient::$client;
    $repo = new GitlabRepo($gl, $triad->gitlabID);
    $invoice = $repo->readFileMaybe('target/invoice-latest.pdf');
    if (is_null($invoice))
    {
        $log->error('The invoice for this pentest is not present in the repository.');
        $log->info('Please use the `rosbot invoice` command first to generate it.');
        throw new Exception('invoice missing');
    }
    $log->info('Invoice found.');
    
    $log->info('Looking up client info...');
    $clientInfo = $repo->readFileMaybe('source/client_info.xml');
    if (is_null($clientInfo))
    {
        $log->error('The required file client_info.xml is not present in the repository.');
        throw new Exception('client info missing');
    }
    $clientInfo = new SimpleXMLElement($clientInfo);
    $clientName = $clientInfo->full_name;
    $invoiceRep = $clientInfo->invoice_rep;
    $invoiceMail = $clientInfo->invoice_mail;
    $vatNumber = $clientInfo->vat_no;
    if (isset($clientInfo->invoice_extra_field))
    {
        $poNumber = $clientInfo->invoice_extra_field;
    }
    else
    {
        $poNumber = 'unknown';
    }
    
    $log->info('Looking up quote data.');
    $quote = $repo->readFileMaybe('source/quote.xml');
    if (is_null($quote))
    {
        $log->error('The required file source/quote.xml is not present in the repository.');
        throw new Exception('quote missing');
    }
    $quote = new SimpleXMLElement($quote);
    $amount = $quote->meta->pentestinfo->fee;
    $amount = $amount . ' ' . $amount->Attributes()['denomination'];
    
    # Format email to notify invoice department.
    
    $toAddress = INVOICE_ADDRESS;
    $toName = INVOICE_ADDRESSEE;
    $toFirstName = explode(' ', $toName, 2)[0];
    $subject = "Invoice ready for {$triad->name}";
    
    $body = "Hi {$toFirstName}!
    
    The project {$triad->name} has shipped.
    
    Client name: $clientName
    Invoice contact: $invoiceRep <$invoiceMail>
    VAT number: $vatNumber
    PO number or other invoice datum: $poNumber
    Amount: $amount
    
    Kind regards from rosbot!
    ";
    
    $mail = new PHPMailer;
    $mail->setFrom('rosbot@radicallyopensecurity.com', 'Rosbot');
    $mail->addAddress($toAddress, $toName);
    // $mail->addReplyTo('info@example.com', 'Information');
    // $mail->addCC('cc@example.com');
    
    $mail->addStringAttachment($invoice, "invoice-{$triad->name}.pdf");
    $mail->isHTML(false);
    
    $mail->Subject = $subject;
    $mail->Body    = $body;
    // $mail->AltBody = 'Contents';
    
    if(!$mail->send())
    {
        $log->error('Email could not be sent. Mailer Error: ' . $mail->ErrorInfo);
        throw new Exception('email sending failed');
    }
    
    $log->info("An email with the invoice has been sent to $toName. Congrats!");
}
catch (Exception $e)
{
    $log->error('Sending invoice failed: ' . $e->getMessage());
}

?>
