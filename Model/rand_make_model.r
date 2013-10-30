## Ryan Himmelwright
## Honors Thesis
## Make Model Script
library(base)
library(igraph)
library(Matrix)
library(methods)
library(lattice)

################################################################################
############################## Defined Functions ###############################
################################################################################
# Function to Generate Small World Graph
MakeSWPNetwork <- function(dimension,size,nei,p){
  swpGraph <- watts.strogatz.game(dimension,size,nei,p, loops = FALSE, multiple = FALSE)
return(swpGraph)
}

# Function to Generate an Erdos-Renyi random graph
MakeRandNetwork <- function(dimension, size, nei, swpGraph){
  # Try to make a random graph with the watts.strogatz.game function
  randGraph <- watts.strogatz.game(dimension,size,nei,1,loops = FALSE, multiple = FALSE)
  return(randGraph)
}

# Finds the hubs of a network.
FindHubs <- function(runCount, hubThreshold, swpGraph){
  hubScore  = hub.score(swpGraph) 
  hubValues = hubScore$vector      # Takes just values from hub score
  # Replaces all hubs with a 1, and other vertices with a 0.
  hubMatrix = replace(replace(hubValues,hubValues >= hubThreshold, 1),
                              hubValues < hubThreshold,0)  
  return(hubMatrix)
}

# Returns the number of hubs in the Matrix
HubCounts <- function(hubMatrix){
  count = sum(hubMatrix == 1)
  return(count)
}


# Calculates S^WS for the network.
CalcSws <- function(swpGraph, randGraph){
  # Calculates clustering coefficients of swp and rand graphs
  swpGamma  =  transitivity(swpGraph, type="global", vids=NULL, weights=NULL,
                            isolates="zero")								
  randGamma = transitivity(randGraph, type="global", vids=NULL, weights=NULL,
                           isolates="zero")                         
  gamma = (swpGamma/randGamma) # combines them to get the Gamma value.

  # Calculates the mean minmal path length for swp and corresponding rand graphs
  swpLambda = average.path.length(swpGraph)
  randLambda = average.path.length(randGraph)
  lambda = (swpLambda / randLambda)  # Combines to get the ratio Lambda value

  Sws = (gamma/lambda) # Calculates S^WS from the ratio.
  
  swsList <- list("Sws" = Sws, "swpPathLength" = swpLambda, 
                  "swpClustering" = swpGamma)
  return(swsList)
}

################################################################################
##############################  Models Functions  ##############################
################################################################################

# Random Model Run. Randomly moves edges.
Run_Random_Model <- function(runCount, swpGraph, randGraph,  hubMatrix,
                             timeSteps){
  runLogOutput = paste('run',runCount,'_logOutput.txt', sep="")
  write(paste('step \t hubCount \t Sws \t avg_Path_Length \t Clustering'), 
        file= runLogOutput, append = TRUE, sep=",")
 print("in model Run now ") 
  # Loops the model for specified amount of time (timeSteps)
  for ( step in seq(from=1, to=timeSteps, by=1)){
    x  <- sample(1:vcount(swpGraph), 1)  # X for swp Graph
    xR <- sample(1:vcount(randGraph), 1) # X for rand graph
    y  <- sample(1:vcount(swpGraph), 1)  # Y for swp graph
    yR <- sample(1:vcount(randGraph), 1) # Y for rand graph
    z  <- sample(1:vcount(swpGraph), 1)  # Z for swp graph
    zR <- sample(1:vcount(randGraph), 1) # Z for rand graph

    # Re-selects x and y if they don't have an edge between them.  
    while( swpGraph[x,y] == 0 & degree(swpGraph)[y] > 1){
      x<- sample(1:vcount(swpGraph), 1)
      y<- sample(1:vcount(swpGraph), 1)
    }
    # Re-selects xR and yR if they don't have a connecting edge.
    while( randGraph[xR,yR] == 0){
      xR <- sample(1:vcount(randGraph),1)
      yR <- sample(1:vcount(randGraph),1)
    }
    swpGraph[x,y]    <- FALSE              # Remove edge between x and y
    randGraph[xR,yR] <- FALSE              # Remove edge between xR and yR

    # Loops new z values until x and z don't have an edge
    while( swpGraph[x,z] == 1){
      z<- sample(1:vcount(swpGraph), 1)
          }
    while( randGraph[xR,zR] == 1){
      zR <- sample(1:vcount(randGraph), 1)
    }
    swpGraph[x,z] <- 1                  # Add edge between x and z
    randGraph[xR,zR] <- 1               # Add edge between xR and zR
    
#    print(swpGraph[])
    print(step)
    
    # Print attributes to output file
    # -------------------------------
    swsList = CalcSws(swpGraph,randGraph)
    swpGamma  =  transitivity(swpGraph, type="global", vids=NULL, weights=NULL)
    write(paste(step,'\t',HubCounts(FindHubs(runCount, hubThreshold, swpGraph)),
          '\t', swsList$Sws,'\t', swsList$swpPathLength,'\t',
          swsList$swpClustering), file= runLogOutput, append = TRUE, sep="," )
  }
}



################################################################################
############################## Printing Functions ##############################
################################################################################
PrintGraphStats <- function(runCount,swp1, rand1, swpGraph, randGraph, hubMatrix,dimension, size,
                            nei, p, hubThreshold){
  # Generate output file of each run in each run directory
  outfileName = "../cumulative_attributes.txt"   
    
  for (i in seq(from=1, to=2, by=1)){
    write('-----', file= outfileName, append = TRUE)
    write(paste('runCount: ', runCount), file= outfileName, append = TRUE, sep= ", ")
    write(paste('dimension: ', dimension), file= outfileName, append = TRUE, sep= ", ")
    write(paste('Size: ',size), file= outfileName, append = TRUE, sep= ", ")
    write(paste('Nei: ', nei), file= outfileName, append = TRUE, sep= ", ")
    write(paste('p: ',p), file= outfileName, append = TRUE, sep= ", ")
    write(paste('hubThreshold: ', hubThreshold), file= outfileName,
          append = TRUE, sep= ", ")

    write('', file= outfileName, append = TRUE)
    write(paste("Orig. Generated Graph:"), file= outfileName, append = TRUE, sep=", ")
    write(paste('swpGraph Vertice count: ', vcount(swp1)), file= outfileName,
          append = TRUE, sep= ", ")
    write(paste('swpGraph Edge count: ',ecount(swp1)), file= outfileName, 
          append = TRUE, sep= ", ")
    write(paste('swpGraph Sws: ', CalcSws(swp1, rand1)$Sws), file= outfileName, append = TRUE, 
          sep= ", ")
    write(paste('swpGraph Hub count: ', sum(hubMatrix == 1)), file= outfileName,
          append = TRUE, sep= ", ")
    write('', file= outfileName, append = TRUE)

    write(paste("After graph cleaning:"), file=outfileName, append = TRUE, sep=", ")
    write(paste('swpGraph Vertice count: ', vcount(swpGraph)), file= outfileName,
          append = TRUE, sep= ", ")
    write(paste('swpGraph Edge count: ',ecount(swpGraph)), file= outfileName, 
          append = TRUE, sep= ", ")
    write(paste('swpGraph Sws: ', CalcSws(swpGraph, randGraph)$Sws), file= outfileName, append = TRUE, 
          sep= ", ")
    write(paste('swpGraph Hub count: ', sum(hubMatrix == 1)), file= outfileName,
          append = TRUE, sep= ", ")
    write('-----', file= outfileName, append = TRUE)
    write('', file= outfileName, append = TRUE)
    outfileName = paste('starting_params.txt', sep="")
    }
}

PlotGraph <- function(runCount, swpGraph, randGraph, hubMatrix){
  # Color hubs in SWP plot.
  for (i in seq(from=1, to= length(hubMatrix), by=1)){
    if(hubMatrix[i] == 1){
      V(swpGraph)$color[i] = "green"
      }
      else{
        V(swpGraph)$color[i] = "cyan"
      }
  }
  ## Plot
  png(file=(paste("SWPplot",runCount,".png",sep="")))
  plot(swpGraph)
  png(file="rand_plot1.png")
  plot(randGraph)
}

################################################################################
################################ Execution Code ################################
################################################################################
args <- commandArgs(trailingOnly = TRUE)
topFolder <- args[1]
name 	  <- args[2]
dimension <- as.numeric(args[3])
size      <- as.numeric(args[4])
nei  	  <- as.numeric(args[5])
p    	  <- as.numeric(args[6])

# Number of runs
trialCount= as.numeric(args[7])
timeSteps = as.numeric(args[8])

setwd(topFolder)


hubThreshold  = 0.8 # The threshold of the centrality score for determing a hub

# Generate Directories for all trials
runCount =1

for( i in seq(from=1, to= trialCount, by=1)){

  print(getwd()) # print current working directory
  
  print(paste('mkdir ',name, sep=""))
  system(paste('mkdir ', name, sep=""))
  setwd(paste(name, sep=""))
  print(getwd())

  #-----------------------------------------------
  #--------------- Model Sequence ----------------
  #-----------------------------------------------

  # Generate Graphs
  # ----------------
  notSWP      = TRUE # true if the graphs are not swp
  notSWPCount = 0
  while(notSWP){
    print("redo") # Re-generating Graph
    notSWPCount = notSWPCount + 1
    print(notSWPCount) # Print re-gen number
    
    # Make New Graphs
    swpGraph = MakeSWPNetwork(dimension,size,nei,p)
    randGraph = MakeRandNetwork(dimension, size, nei, swpGraph)

    if(CalcSws(swpGraph, randGraph)$Sws > 1) notSWP=FALSE
    if(notSWPCount >= 1000){
	  write(paste('Could not generate SWP graph in ', notSWPCount, 
	  	            ' tries.'), file= 'failed.txt', append = TRUE, sep= ", ")
	  quit(save = "no")
    }
    }    
    
    print("Start steps")


  # Clean Graphs
  # ------------
  swpDeadNodes = (which(degree(swpGraph) < 1))
  randDeadNodes= (which(degree(randGraph) < 1))

  print(length(swpDeadNodes))
  print(length(randDeadNodes))
  # Copies saved for printing comparisons
  swp1  <- swpGraph
  rand1 <- randGraph

  # Removes unconnected nodes from generated graphs.
  print("pre initial clean")
  swpGraph  <- delete.vertices(swpGraph, swpDeadNodes)
  randGraph <- delete.vertices(randGraph, randDeadNodes)
  print("post initial clean")

  deadNodeLengths  = c(length(swpDeadNodes), length(randDeadNodes))
  extraDead <- (deadNodeLengths[1] - deadNodeLengths[2])

  if( extraDead > 0 ){
    print("if 1")
  # remove abs() random nodes from rand
    startE <- ecount(randGraph)
    randGraph <- delete.vertices(randGraph,sample(1:vcount(randGraph),
                                 abs(extraDead)))
    endE <- ecount(randGraph)

    # Adds edges until the starting number is reached.
    while( ecount(randGraph) < startE){
      randGraph <- add.edges(randGraph, sample(1:vcount(randGraph),2),
                             multiple = FALSE, loops = FALSE)
    }

  }else if( extraDead < 0){
    print("if 2")
    # remove abs() random nodes from swp
    startE <- ecount(swpGraph)
    swpGraph <- delete.vertices(swpGraph,sample(1:vcount(swpGraph),
                                abs(extraDead)))
    endE <- ecount(swpGraph)

    # Adds edges until the starting number is reached.
    while( ecount(swpGraph) < startE){
      swpGraph <- add.edges(swpGraph, sample(1:vcount(swpGraph),2),
                            multiple = FALSE, loops = FALSE )
    }

  }else{
    # Both equal, do nothing?
  }



    # Run functions on Graphs
    # ------------------------
    hubMatrix = FindHubs(runCount, hubThreshold, swpGraph)
    PrintGraphStats(runCount,swp1, rand1,  swpGraph, randGraph, hubMatrix, dimension, size, nei, p,
                    hubThreshold)
#    plotGraph = PlotGraph(runCount, swpGraph, randGraph, hubMatrix)
#    rand_Model_Run = Run_Random_Model(runCount,swpGraph, randGraph, hubMatrix,
#                                     timeSteps)


    # Increment for next run
    # ----------------------
    runCount = runCount + 1
    setwd("..") # Go up a directory
}
print(warnings())
