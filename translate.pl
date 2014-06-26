#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use File::ReadBackwards;
use File::Copy;
use Text::Diff;

my $sepCar = "[,\|]";
my $comCar = "#";
my $comCarForLang = "#";

my $rulesFile = "rules.tsl";
my $knowsFile = "knows.tsl";
my $usersFile = "users.tsl";
#my $file = "GenIllu.m";
my $file = "test.txt";

my $newExt = ".jl";
my $askForLoadKnows = "false";

my $newFile = $file ;
$newFile =~ s/\.\w+$/$newExt/;

my $endLineCodeOrg = $comCarForLang."org";
my $endLineCodeUsr = "		".$comCarForLang."usr";

my $useUserLines ="false";



my @PILE = ();
my @TODOPARA = ();

sub debug_regex
{
	print("1 :  $1\n") if(defined( $1));
	print("2 :  $2\n") if(defined( $2));
	print("3 :  $3\n") if(defined( $3));
	print("4 :  $4\n") if(defined( $4));
	print("5 :  $5\n") if(defined( $5));
	print("6 :  $6\n") if(defined( $6));
	print("7 :  $7\n") if(defined( $7));
	print("8 :  $8\n") if(defined( $8));
	print("9 :  $9\n") if(defined( $9));
	print("10 : $10\n") if(defined($10));
	print("11 : $11\n") if(defined($11));
	print("12 : $12\n") if(defined($12));
	print("13 : $13\n") if(defined($13));
}

sub push_Paragraph
{
	my( $refParagraph, $Pr, $So, $In, $Sc, $Po) = @_;
	#print("Debut push Paragraph\n");
	my $curRefRules = 0;
	my $numParagraph = -1;
	$Pr = "" unless( defined($Pr));
	$In = "\.+" unless( defined($In));
	$Po = "" unless( defined($Po));
	if(defined($So) and defined($Sc) )
	{
		#$$refParagraph[0]  :  simple Array of definition of paragraph and array of rules to apply
		#$$refParagraph[1]  :  search tree for paragraph		
		#$$refParagraph[2]  :  correspondence under opener and closer
		unless(defined($$refParagraph[0]))
		{
			my @tempArray = ();
			$$refParagraph[0] = \@tempArray;
			#print("	Init 1 \n");
		}
		unless(defined($$refParagraph[1]))
		{
			my %tempHash = ();
			$$refParagraph[1] = \%tempHash;
			#print("	Init 2 \n");
		}
		unless(defined($$refParagraph[2]))
		{
			my %tempHash = ();
			$$refParagraph[2] = \%tempHash;
			#print("	Init 3 \n");
		}
		

		if(defined(${$$refParagraph[2]}{$So}))
		{	
			print("	Problem : One SO have two different SC\n") unless( ${$$refParagraph[2]}{$So} eq $Sc );
		}
		else
		{
			${$$refParagraph[2]}{$So} = $Sc;
		}
		
		my $tpVal = @{$$refParagraph[0]};
		my %tpHsPo = ($Po => $tpVal);
		my $tpRefHsPo = \%tpHsPo;
		my %tpHsIn = ($In=> $tpRefHsPo);
		my $tpRefHsIn = \%tpHsIn;
		my %tpHsPr = ($Pr=> $tpRefHsIn);
		my $tpRefHsPr = \%tpHsPr;
		my %tpHsSo = ($So=> $tpRefHsPr);
		my $tpRefHsSo = \%tpHsSo;

		my $curSearchStruct = $$refParagraph[1];
		if(defined($$curSearchStruct{$So}))
		{
			$curSearchStruct = $$curSearchStruct{$So};
			if(defined($$curSearchStruct{$Pr}))
			{
				$curSearchStruct = $$curSearchStruct{$Pr};
				if(defined($$curSearchStruct{$In}))
				{
					$curSearchStruct = $$curSearchStruct{$In};
					if(defined($$curSearchStruct{$Po}))
					{
						#print("	Paragraph already used\n");
						$numParagraph = $$curSearchStruct{$Po};
					}		
				}
				else
				{
					$$curSearchStruct{$In} = $tpRefHsPo;
				}
			}
			else
			{
				$$curSearchStruct{$Pr} = $tpRefHsIn;
			}
		}
		else
		{
			$$curSearchStruct{$So} = $tpRefHsPr;
		}
		
		#print("	$numParagraph\n");
		
		if($numParagraph == -1)
		{
			my @tempArray = ();
			$curRefRules = \@tempArray;
			#print("	ref array rules for this paragraph init : $curRefRules \n");
			#$numParagraph = @{$$refParagraph[0]};
			#my $refvv = $$refParagraph[0];
			push( @{$$refParagraph[0]}, [$Pr, $So, $In, $Sc, $Po,$curRefRules]);
			#$refvv = $$refParagraph[0];
		}
		else
		{
			my $refArrayPara = $$refParagraph[0];
			my $refTmpPar = $$refArrayPara[$numParagraph];
			$curRefRules = $$refTmpPar[5];
		}		
	}
	else
	{
		print("	Probleme So or Sc not defined for one rules for paragraph\n");
	}
	
	my $tej = $$refParagraph[0];
	#print("	ref array : $tej  \n");
	#print("Fin push Paragraph\n\n\n");
	return $curRefRules;
}

sub load_rules
{
	my ($refRules,$refParagraph,$refKnows,$file) = @_;
	my $itrKwd = '\s*((\S+)|(".*"))*\s*';
	
	if(open RULES, "<".$file)
	{
		foreach my $line (<RULES>)
		{
			my $curRefRules = $refRules;
			if( (($line =~ /^\s*(\S+)\s*->\s*"(.*)"/) or ($line =~ /^\s*(\S+)\s*->\s*(\S*)/) ) and !($line =~ /^\s*$comCar/) )
			{
				my $regText = $1;
				my $replaceText = $2;
				my @cond = ();
				my @action = ();
				my @add = ();
				my $numParagraph = -1;
				if( $line =~ /\s+if(\s+\$\d+\s+is\s+\S+(\s+$sepCar\s*\$\d+\s*is\s+\S+)*)/)
				{
					my @match = split("$sepCar",$1);
					foreach my $tMatch (@match)
					{
						$tMatch =~ /^\s*\$(\d+)\s+is\s+(\S+)\s*$/;
						push(@cond, [$1,$2]);
					}
				}
				if( $line =~ /\s+act(\s+\S+(\s*$sepCar\s*\S+)*)/)
				{
					my @match = split("$sepCar",$1);
					foreach my $tMatch (@match)
					{
						$tMatch =~ /^\s*(\S+)\s*$/;
						push(@action, $1);
					}
				}
				if( $line =~ /\s+add(\s*\$\d\s*is((not)*)\s+\w+(\s*$sepCar\s*\$\d\s*is((not)*)\s+\w+)*)/)
				{
					my @match = split("$sepCar",$1);
					foreach my $tMatch (@match)
					{
						$tMatch =~ /^\s*\$(\d)\s*is((not)*)\s+(\w+)\s*$/;
						push(@add, [$1,$4,0]) if ($2 eq "not");
						push(@add, [$1,$4,1]) if ($2 eq "");
					}
				}
				if( $line =~ /\s+PR${itrKwd}SO${itrKwd}IN${itrKwd}SC${itrKwd}PO${itrKwd}/ )
				#elsif( ( $line =~ /^\s*PR\s*"(.*)"\s*SO/ ) and !($line =~ /^\s*$comCar/) )
				{
					#print("Case detected : \n");
					#debug_regex();
					#print("$line\n");
					$curRefRules = push_Paragraph($refParagraph,$1,$4,$7,$10,$13);
				}

				push(@$curRefRules,[$regText,$replaceText,\@cond,\@action,\@add]);	
			}
			elsif ($line =~ /^\s*init\s+/)
			{
				if($line =~ /\s+add(\s+\w+\s+is((not)*)\s+\w+(\s*$sepCar\s*\w+\s+is((not)*)\s+\w+)*)/)
				{
					my @match = split("$sepCar",$1);
					foreach my $tMatch (@match)
					{
						$tMatch =~ /^\s*(\w+)\s*is((not)*)\s+(\w+)\s*$/;
						my $name = $1;
						my $is = $4;
						#push(@knows,[$name,$is]);	
						add_know($refKnows,$name,$is,0) if($2 eq "not");
						add_know($refKnows,$name,$is,1) unless($2 eq "not");
					}
				}
			}
			else
			{	
				print("Wrong rule : $line\n") unless(($line =~ /^\s+$/ ) or ($line =~ /^\s*$comCar/) );
			}	
		}
		close RULES;
	}
	else
	{
	print("Rules file not found !!!\n");
	}
}


sub isIn
{
	my ($isA, $realIsA) = @_;
	return ( ($realIsA =~ /$sepCar\s*$isA\s*$sepCar/) or ($realIsA =~ /^\s*$isA\s*$sepCar/) or ($realIsA =~ /$sepCar\s*$isA\s*$/) or ($realIsA =~ /^$isA$/));
}

sub add_know
{
	my ($refKnows, $name, $isA, $really) = @_;
	if(defined ${$$refKnows{$name}}[$really] )
	{
		${$$refKnows{$name}}[$really]  .=",$isA" unless(isIn($isA,${$$refKnows{$name}}[$really]));
	}
	else
	{
		${$$refKnows{$name}}[$really]  = "$isA";
	}
}

sub load_knows
{
	my ($refKnows,$file) = @_;
	if(open KNOWS, "<".$file)
	{
		foreach my $line (<KNOWS>)
		{
			if( $line =~ /^\s*(\S+)\s*is((not)*)\s*(\w+)((\s*,\s*\w+)*)\s*$/)
			{
				my $name = $1;
				my $is = $4;
				$is .=$5 if($5);
				#push(@knows,[$name,$is]);	
				add_know($refKnows,$name,$is,0) if($2 eq "not");
				add_know($refKnows,$name,$is,1) unless($2 eq "not");
			}
			else
			{	
				print("Wrong know : $line\n") unless($line =~ /^\s+$/ );
			}	
		}
		close KNOWS;
	}
}


sub write_know
{
	my ($name, $know,$really) = @_;
	print _KNOWS "$name  is $know\n" if( (defined $know) and ($really==1));
	print _KNOWS "$name isnot $know\n" if( (defined $know) and ($really==0));
}

sub write_knows
{
	my ($refKnows,$file) = @_;
	open _KNOWS, "+>".$file;
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
	print("	rule : $$refRule[0]  ->  $$refRule[1]\n");
	foreach my $cond (@{$$refRule[2]})
	{
		my @tCond = @{$cond};
		print("	Cond : $tCond[0] is $tCond[1]\n");
	}
	foreach my $action (@{$$refRule[3]})
	{
		print("	Action : $action\n");
	}
	foreach my $add (@{$$refRule[4]})
	{
		my @tAdd = @{$add};
		print("	Add : $tAdd[0] is $tAdd[1]\n") if( $tAdd[2] == 1);
		print("	Add : $tAdd[0] isnot $tAdd[1]\n") if( $tAdd[2] == 0);
	}
}

sub print_know
{
	my ($name, $know,$really) = @_;
	print(" know : $name is $know\n") if( (defined $know) and ($really==1));
	print(" know : $name isnot $know\n") if( (defined $know) and ($really==0));
}

sub print_paragraph
{
	my($refParagraph) = @_;
	print("\n  Paragraph :");
	print("PR $$refParagraph[0] SO $$refParagraph[1] IN $$refParagraph[2] SC $$refParagraph[3] PO $$refParagraph[4]\n");
	my $size = @{$$refParagraph[5]};
	#print("Size rules for para : $size\n");
	foreach my $rule ( @{$$refParagraph[5]})
	{
		print_rule($rule);
	}
}

sub print_rules
{
	my ($refRules,$refParagraph) = @_;
	print("\n-----------------------\n");
	print("Rules : \n\n");
	print("  Global : \n");
	#my $count = -1;
	foreach my $temp (@$refRules)
	{	
			print_rule($temp);
	}
	#my $size = @{$$refParagraph[0]};
	#print("Size $size\n");
	if(defined($refParagraph))
	{
		foreach my $paragraph (@{$$refParagraph[0]})
		{
			print_paragraph($paragraph);
		}
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

sub replace_if_ok
{
	my ($text,$regText,$replaceTextOrg,$replaceText,$isOk,$print,$pMatch) = @_;
	if( ($isOk eq "true") and ($print eq "true") )
	{
		print("\n|$text|\n");
		print("\n|$regText|\n");
		#print("\n|$replaceTextOrg|\n");
		print("\n|$replaceText|\n");
		print("\n---------------------------------\n");
	}
	return  $replaceText if($isOk eq "true");
	return $pMatch;
}

sub treatment_match
{
	my ($text,$refKnows,$refCond,$refAction,$refAdd,$refOutput,$replaceTextOrg,$refIsModif, @match )= @_;
	my $isOk = "true";
	my $regText = $match[0];
	#print("\nbefore |$replaceText|\n");
	my $replaceText = eval "\"$replaceTextOrg\"";
	#print("\nafter |$replaceText|\n");
	my $print = "false";
	my $ask = "false";
	my $stop = "false";
	my $debug = "false";
	
	
	foreach my $tAction (@$refAction)
	{
		$print = "true" if($tAction eq "print");
		$ask = "true" if($tAction eq "ask");
		$stop ="true" if($tAction eq "stop");
		$debug = "true" if($tAction eq "debug");
	}
	
	if( @match>1 )
	{
		foreach my $tCond (@$refCond)
		{
			my $numMatch = $$tCond[0];
			my $isA = $$tCond[1];
			if(defined $match[$numMatch] ) 
			{
				my $tempMatch = $match[$numMatch];
				if($debug eq "true")
				{
					print("\n$text\n");
					print (" numMatch :$numMatch , isA : $isA\n");
					print("$tempMatch\n") ;
				}
				$tempMatch =~ s/\s//;
				if( exists $$refKnows{ $tempMatch} ) 
				{
					if(defined ${$$refKnows{$tempMatch}}[1])
					{
						my $realIsA = ${$$refKnows{$tempMatch}}[1];
						$isOk = "false" unless( isIn($isA,$realIsA));
					}
					if(defined ${$$refKnows{$tempMatch}}[0])
					{
						my $realIsA = ${$$refKnows{$tempMatch}}[0];
						$isOk = "false" if( isIn($isA,$realIsA));						
					}
				}
				else
				{
					if($ask eq "true")
					{
						my $element = $tempMatch;
						print("\n\n$text\n");
						print("$element is a $isA ? (y/n)\n");
						my $var = "";
						while( ($var ne "n\n") and ($var ne "y\n") and ($var ne "q\n") )
						{
							#print("|$var|\n");
							$var = <STDIN>
						}
						save_and_stop($refKnows) if($var eq "q\n");
						$$refIsModif = "true";
						add_know($refKnows,$element,$isA,1) if($var eq "y\n");
						add_know($refKnows,$element,$isA,0) if($var eq "n\n");						
						$isOk = "false" if($var eq "n\n");
					}
					else
					{
						$isOk = "false";
					}
				}
			}
		}
		
		if($isOk eq "true")
		{
			foreach my $tAdd (@$refAdd)
			{
				my $numMatch = $$tAdd[0];
				my $isA = $$tAdd[1];
				my $var = $$tAdd[2];
				if(defined $match[$numMatch] ) 
				{
					my $element = $match[$numMatch];
					if(defined ${$$refKnows{$match[$numMatch]}}[$var])
					{
						my $realIsA = ${$$refKnows{$match[$numMatch]}}[$var];
						$$refIsModif = "true" if(!isIn($isA,$realIsA) );
					}
					else
					{
						$$refIsModif = "true";
					}
					add_know($refKnows,$element,$isA,$var);
				}
			}
		}
	}
	if( ($isOk eq "true") and ($stop eq "true"))
	{
		$$refOutput ="stop";
	}
	return replace_if_ok($text,$regText,$replaceTextOrg,$replaceText,$isOk,$print,$match[0]);
}

sub apply_paragraphs
{
	my ($text, $predText, $refParagraphs, $refKnows,$refIsModif) = @_;		
	#$$refParagraph[0]  :  simple Array of definition of paragraph and array of rules to apply
	#$$refParagraph[1]  :  search tree for paragraph		
	#$$refParagraph[2]  :  correspondence under opener and closer
	
	my $refSearchTree = $$refParagraphs[1];

	foreach my $paragraph ( keys( %$refSearchTree ))
	{
		print(" para : $paragraph\n");
	#	#print_rule($rule);
	#	my $regText = @{$rule}[0];
	#	my $replaceText = @{$rule}[1];
	#	my $refCond =@{$rule}[2];
	#	my $refAction =@{$rule}[3];
	#	my $refAdd =@{$rule}[4];
	#	my $output ="";
	#	my $refOutput =\$output;
	#			
	#	#all the magic is here 
	#	$text =~ s/$regText/eval 'treatment_match($text,$refKnows,$refCond,$refAction,$refAdd,$refOutput,$replaceText,$refIsModif,$&,$1,$2,$3,$4)'/eg;
	#	
	#	#my @match = $text =~ /$regText/	;
	#	if($output eq "stop")
	#	{
	#		last;
	#	}
	#	
	}
	return $text;
}


sub apply_rules
{
	my ($text, $predText, $refRules, $refKnows,$refIsModif) = @_;
	#my @rules = @{$refRules};
	#my %knows = %{$refKnows};
		
	foreach my $rule (@$refRules)
	{
		#print_rule($rule);
		my $regText = @{$rule}[0];
		my $replaceText = @{$rule}[1];
		my $refCond =@{$rule}[2];
		my $refAction =@{$rule}[3];
		my $refAdd =@{$rule}[4];
		my $output ="";
		my $refOutput =\$output;
				
		#all the magic is ear 
		$text =~ s/$regText/eval 'treatment_match($text,$refKnows,$refCond,$refAction,$refAdd,$refOutput,$replaceText,$refIsModif,$&,$1,$2,$3,$4)'/eg;
		
		#my @match = $text =~ /$regText/	;
		if($output eq "stop")
		{
			last;
		}
		
	}
	return $text;
}

sub trans_text
{
	my ($file,$tFile,$refRules,$refParagraphs,$refKnows,$refIsModif,$refUserLine)=@_;
	if(open FILE, "<".$file)
	{
		open TFILE, ">".$tFile;
		my $size = 0; 
		if( (defined $refUserLine) and (@{$$refUserLine[0]} > 0) )
		{
			$size = @{$$refUserLine[0]};
		}
		my $count=0;
		my $lCount=0;
		my $continue = 1;
		my $curLine;
		my $predLine;
		my $valCur = 0;
		my $valPred = 0;
		while( $continue)
		{
			my $isOk =1;
			if($count<$size)
			{
				$valCur = ${$$refUserLine[0]}[$count];
				# $valCur :  0 mean same line in both file 
				# 	    	 1 mean line just in FILE 
				#  			 2 mean line just in TFILE
				# so 1 follow by 2 mean modified line
				if ($valCur == 1)
				{
					$isOk=0;
				}
				if($valCur == 2)
				{
					$isOk=0;
					$predLine = $curLine;
					if(defined($curLine = <FILE>)) 
					{
						if($valPred == 1)
						{
							my $predLine = ${$$refUserLine[1]}[$lCount];
							if($predLine =~ /$endLineCodeOrg\s*$/)
							{
								$curLine =~ s/\s*$//;
								my $line = apply_paragraphs($curLine, $predLine,$refParagraphs,$refKnows,$refIsModif);
								$line = apply_rules($line, $predLine,$refRules,$refKnows,$refIsModif);
								#my $line = apply_rules($curLine, $predLine,$refRules,$refKnows,$refIsModif);
								print TFILE "$line\n";								
							}
							else
							{
								if($predLine =~ /$endLineCodeUsr$/)
								{
									print TFILE $predLine."\n";		
								}
								else
								{
									if( $predLine =~ /^\s*$/)
									{
										print TFILE $predLine."\n";		
									}
									else
									{
										print TFILE $predLine.$endLineCodeUsr."\n";		
									}
								}
							}
							$lCount++;
						}
					}
				}
				if( ($valPred == 1) and ( ($valCur == 0) or ($valCur == 1) ) )
				{
					my $tempLine = ${$$refUserLine[1]}[$lCount];
					if($tempLine =~ /$endLineCodeUsr$/)
					{
						print TFILE $tempLine."\n";		
					}
					else
					{
						if( $tempLine =~ /^\s*$/)
						{
							print TFILE $tempLine."\n";		
						}
						else
						{
							print TFILE $tempLine.$endLineCodeUsr."\n";		
						}
					}
					$lCount++;
				}		
				$valPred = $valCur;
			}
			
			if($isOk==1)
			{
				$predLine = $curLine;
				if($curLine = <FILE>)
				{
					$curLine =~ s/\s*$//;
					my $line = apply_paragraphs($curLine, $predLine,$refParagraphs,$refKnows,$refIsModif);
					$line = apply_rules($line, $predLine,$refRules,$refKnows,$refIsModif);
					#my $line = apply_rules($curLine, $predLine,$refRules,$refKnows,$refIsModif);
					print TFILE "$line\n";		
				}
				else
				{
					$continue = 0;
					if ($valCur == 1)
					{
						print TFILE ${$$refUserLine[1]}[$lCount]."\n";		
						$lCount++;
					}
				}
			}
			$count++;
		}
		
		close FILE;
		close TFILE;
	}
	else
	{
		print("\nProblem open file : $file\n");
	}
}

sub boucle_trans_text
{
	my ($file,$newFile,$refRules,$refParagraphs,$refKnows,$refUserLine)=@_;
	my $isModif = "true";
	my $refIsModif = \$isModif;
	while($isModif eq "true")
	{
		$isModif = "false";
		trans_text($file,$newFile,$refRules,$refParagraphs,$refKnows,$refIsModif,$refUserLine);
	}
}


sub save_and_stop
{
	my ($refKnows) = @_;
	write_knows($refKnows,$knowsFile);
	exit;
}

sub save_copy
{
	my $memKnowsFile ="mem".$knowsFile;
	my $memRulesFile ="mem".$rulesFile;
	$memKnowsFile =~ s/\.\w+$//;
	$memRulesFile =~ s/\.\w+$//;
	copy($knowsFile,$memKnowsFile) or die "Copy failed: $!"if( -f $knowsFile);
	copy($rulesFile,$memRulesFile) or die "Copy failed: $!"if( -f $rulesFile);
	print("RulesFile : $rulesFile	 not found") unless( -f $rulesFile);
}


sub load_user_line
{
	my ($refUserLine) = @_;
	my $diff = calc_diff_file();
	my @lines = split("\n",$diff);
	my $count = 0;
	my $sum = 0;
	my $memPrevSum = 1;
	my @todo = ();
	my @ligne = ();
	foreach my $line (@lines) 
	{
		if($count>=2)
		{
			if($line =~ /^@@ \-(\d+),(\d+) \+\d+,\d+ @@\s*$/)
			{
				$sum = $1-$memPrevSum;
				foreach my $i (1..$sum) 
				{
					push(@todo,0);
				}
				$memPrevSum = $1+$2
			}
			else
			{
				my $cur = 0;
				if($line =~ /^\-(.*)$/)
				{
					$cur = 1;
					push(@ligne,$1);
				}
				$cur = 2 if($line =~ /^\+/);
				push(@todo,$cur);
			}
		}
		#print("$line\n");
		$count++;
	}
	undef($diff);
	push(@$refUserLine,(\@todo,\@ligne));
	#foreach my $line (@userLine) 
	#{
	#	print("$line\n");
	#}
}

sub calc_diff_file
{
	my @tempRules = ();
	my $tempRefRules = \@tempRules;
	my %tempKnows = ();
	my $tempRefKnows = \%tempKnows;
	my @tempParagraph = (); 
	my $tempRefParagraphs = \@tempParagraph;
	my $tempRulesFile = "mem".$rulesFile;
	my $tempKnowsFile = "mem".$knowsFile;
	$tempKnowsFile =~ s/\.\w+$//;
	$tempRulesFile =~ s/\.\w+$//;
	my $tempFile = "mem".$file;
	$tempFile =~ s/\.\w+$//;
	my $diff = "";
	if( -f $tempRulesFile and -f $tempRulesFile and -f $file and -f $newFile)
	{
		load_rules($tempRefRules,$tempRefParagraphs,$tempRefKnows,$tempRulesFile);
		load_knows($tempRefKnows,$tempKnowsFile);
		boucle_trans_text($file,$tempFile,$tempRefRules,$tempRefParagraphs,$tempRefKnows,);
		my %options = ( STYLE => "Context" );
		my $bw = File::ReadBackwards->new( $newFile )
        or die "Could not read backwards in [$newFile]: $!";
		my $ttligne = 	$bw->readline; 		
		if($ttligne =~/\S$/)
		{
			open NFILE,"+<".$newFile;
			seek(NFILE,0,2);
			print NFILE "\n\n";
			close NFILE;
		}
		$diff = diff $newFile => $tempFile;
	}
	else
	{
		print("No memorie file, normal if first execution.\n");
	}
	return $diff;
}


############################	CALC USER LINES		##############################################
my $refUserLine;
if( $useUserLines eq "true")
{
	my @userLine = ();
	$refUserLine =  \@userLine;
	load_user_line($refUserLine);
	print("\n\n\n-----------------------------------------------------------------\n");
	print("		User Line loaded\n");
	print("-----------------------------------------------------------------\n\n\n");
}
else
{
	print("\n------------ User Line desactived ------------\n\n\n ");
}
#print("@{$userLine[0]}\n");
#print("@{$userLine[1]}\n");

############################	LOAD RULES AND KNOWS	##############################################

my @rules = ();
my $refRules = \@rules;
my @Paragraph = ();
my $refParagraphs = \@Paragraph;

my %knows = ();
my $refKnows = \%knows;

save_copy();
load_rules($refRules,$refParagraphs,$refKnows,$rulesFile);

print("\n\nYou want to load previous knows or to erase them ?(l/e)");
my $var = "";
$var = "l\n" if ($askForLoadKnows eq "false");
while( ($var ne "l\n") and ($var ne "e\n") )
{
	$var = <STDIN>
}
if($var eq "l\n")
{
	print("\nLoad knows\n");
	load_knows($refKnows,$knowsFile);	
}

print("\n\n\n-----------------------------------------------------------------\n");
print("		Rules and knows loaded\n");
print("-----------------------------------------------------------------\n\n\n");

############################	PRINT RULES AND KNOWS	##############################################

print_rules($refRules,$refParagraphs);
print_knows($refKnows);

############################	PROCESSING	##############################################
boucle_trans_text($file,$newFile,$refRules,$refParagraphs,$refKnows,$refUserLine);
	
############################	WRITE NEW KNOWS	##############################################
write_knows($refKnows,$knowsFile);

	
	
	
	
	
		