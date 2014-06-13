#!/usr/bin/perl
use strict;
use warnings;
use Cwd;

my $sepCar = "[,\|]";

sub load_rules
{
	my ($refRules) = @_;
	open RULES, "<"."rules.txt";
	foreach my $line (<RULES>)
	{
		if( $line =~ /^\s*(\S+)\s*->\s*(\S*)/)
		{
			my $regText = $1;
			my $replaceText = $2;
			my @cond = ();
			if( $line =~ /\s+if(\s+\d+\s+is\s+\S+(\s+$sepCar\s*\d+\s*is\s+\S+)*)\s*$/)
			{	
				my @match = split("$sepCar",$1);
				foreach my $tMatch (@match)
				{
					#print("match : $tMatch\n");
					$tMatch =~ /^\s*(\d+)\s+is\s+(\S+)\s*$/;
					push(@cond, [$1,$2]);
				}
			}
			push(@$refRules,[$regText,$replaceText,\@cond]);	
		}
		else
		{	
			print("Wrong rule : $line\n") unless($line =~ /^\s+$/ );
		}	
	}
	close RULES;
}

sub isIn
{
	my ($isA, $realIsA) = @_;
	return ( ($realIsA =~ /[,\W]$isA[,\W]/) or ($realIsA =~ /^$isA[,\W]/) or ($realIsA =~ /[,\W]$isA$/) or ($realIsA =~ /^$isA$/));
}

sub add_know
{
	my ($refKnows, $name, $isA, $really) = @_;
	if(defined ${$$refKnows{$name}}[$really] )
	{
		${$$refKnows{$name}}[$really]  .=",$isA" unless(isIn($isA,$$refKnows{$name}));
	}
	else
	{
		${$$refKnows{$name}}[$really]  = "$isA";
	}
}

sub load_knows
{
	my ($refKnows) = @_;
	open KNOWS, "<"."knows.txt";
	foreach my $line (<KNOWS>)
	{
		if( $line =~ /^\s*(\S+)\s*(!*)=\s*(\w+)((\s*,\s*\w+)*)\s*$/)
		{
			my $name = $1;
			my $is = $3;
			$is .=$4 if($4);
			#push(@knows,[$name,$is]);	
			add_know($refKnows,$name,$is,0) if($2 eq "!");
			add_know($refKnows,$name,$is,1) unless($2 eq "!");
		}
		else
		{	
			print("Wrong know : $line\n") unless($line =~ /^\s+$/ );
		}	
	}
	close KNOWS;
}
sub write_know
{
	my ($name, $know,$really) = @_;
	print _KNOWS "$name  = $know\n" if( (defined $know) and ($really==1));
	print _KNOWS "$name != $know\n" if( (defined $know) and ($really==0));
}

sub write_knows
{
	my ($refKnows) = @_;
	open _KNOWS, "+>"."knows.txt";
	foreach my $temp (keys(%$refKnows))
	{	
		write_know($temp, ${$$refKnows{$temp}}[0],0);
		write_know($temp, ${$$refKnows{$temp}}[1],1);
	}	
	close _KNOWS;
}

sub print_rule
{
	my ($refRule) = @_;
	print(" rule : $$refRule[0]  ->  $$refRule[1]\n");
	foreach my $cond (@{$$refRule[2]})
	{
		my @tCond = @{$cond};
		print("Cond : $tCond[0] is $tCond[1]\n");
	}
}

sub print_know
{
	my ($name, $know,$really) = @_;
	print(" know : $name   = $know\n") if( (defined $know) and ($really==1));
	print(" know : $name  != $know\n") if( (defined $know) and ($really==0));
}

sub print_rules
{
	my ($refRules) = @_;
	print("\n-----------------------\n");
	print("Rules : \n\n");
	foreach my $temp (@$refRules)
	{	
		print_rule($temp);
	}	
	print("-----------------------\n");
}

sub print_knows
{
	my ($refKnows) = @_;
	print("\n-----------------------\n");
	print("Knows : \n\n");
	foreach my $temp (keys(%$refKnows))
	{	
		print_know($temp, ${$$refKnows{$temp}}[0],0);
		print_know($temp, ${$$refKnows{$temp}}[1],1);
	}	
	print("-----------------------\n");
}

sub apply_rules
{
	my ($text, $refRules, $refKnows) = @_;
	#my @rules = @{$refRules};
	#my %knows = %{$refKnows};
	foreach my $rule (@$refRules)
	{
		#print_rule($rule);
		my $regText = @{$rule}[0];
		my $replaceText = @{$rule}[1];
		my @cond =@{@{$rule}[2]};
		my $isOk = "true";
		my @match = $text =~ /$regText/	;
		if( @match>0 )
		{
			foreach my $tCond (@cond)
			{
				my $numMatch = $$tCond[0];
				my $isA = $$tCond[1];
				#print (" numMatch :$numMatch , isA : $isA\n");
				#my $temp = $match[$numMatch-1] if($numMatch <= @match);
				#print("$temp\n") if($numMatch <= @match);
				if($numMatch <= @match) 
				{
					if( exists $$refKnows{ $match[$numMatch-1]} ) 
					{
						if(defined ${$$refKnows{$match[$numMatch-1]}}[1])
						{
							my $realIsA = ${$$refKnows{$match[$numMatch-1]}}[1];
							$isOk = "false" unless( isIn($isA,$realIsA));
						}
						if(defined ${$$refKnows{$match[$numMatch-1]}}[0])
						{
							my $realIsA = ${$$refKnows{$match[$numMatch-1]}}[0];
							$isOk = "false" if( isIn($isA,$realIsA));						
						}
					}
					else
					{
						my $element = $match[$numMatch-1];
						print("\n\n$text\n");
						print("$element is a $isA ? (y/n)\n");
						my $var = "";
						while( ($var ne "n\n") and ($var ne "y\n") )
						{
							#print("|$var|\n");
							$var = <STDIN>
						}
						add_know($refKnows,$element,$isA,1) if($var eq "y\n");
						add_know($refKnows,$element,$isA,0) if($var eq "n\n");						
						$isOk = "false" if($var eq "n\n");
					}
				}
			}
			print("\n---------------------------------\n");
			print("\n|$text|\n");
			print("\n|$regText|\n");
			print("\n|$replaceText|\n");
			$text =~ s/$regText/$replaceText/ if($isOk eq "true");
			print("\n|$text|\n"); 
			print("\n---------------------------------\n");
		}
		else
		{
			print("\n---------------------------------\n");
			print("\n|$text|\n");
			print("\n|$regText|\n");
			print("\n|$replaceText|\n");
			$text =~ s/$regText/$1/;
			print("\n|$text|\n");
			print("\n---------------------------------\n");
		}
	}
	return $text;
}

sub trans_text
{
	my ($file,$newExt,$refRules,$refKnows)=@_;
	my $tFile = $file ;
	$tFile =~ s/\.\w+$/$newExt/;
	if(open FILE, "<".$file)
	{
		open TFILE, ">".$tFile;
		
		while( my $curLigne = <FILE>)
		{
			$curLigne =~ s/\s*$//;
			my $ligne = apply_rules($curLigne,$refRules,$refKnows);
			print TFILE "$ligne\n";		
		}
		
		close FILE;
		close TFILE;
	}
	else
	{
		print("\nProblem open file : $file\n");
	}
}




############################	LOAD RULES AND KNOWS	##############################################

my @rules = ();
my $refRules = \@rules;
my %knows = ();
my $refKnows = \%knows;

print("\n\nYou want to load previous knows or to erase them ?(l/e)");
my $var = "l\n";#"";#
while( ($var ne "l\n") and ($var ne "e\n") )
{
	$var = <STDIN>
}
if($var eq "l\n")
{
	print("\nLoad knows\n");
	load_knows($refKnows);	
}

load_rules($refRules);

############################	PRINT RULES AND KNOWS	##############################################
print_rules($refRules);
print_knows($refKnows);

############################	PROCESSING	##############################################
trans_text("test.txt",".m",$refRules,$refKnows);


############################	WRITE NEW KNOWS	##############################################
write_knows($refKnows);

	
	
	
	
	
	