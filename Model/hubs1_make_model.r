## Ryan Himmelwright
## Honors Thesis
## Make Model Script
library(base)
library(igraph)
library(Matrix)
library(methods)
library(lattice)

# Generate Random Seed Value
seedValue <- sample(1:50000,1)
set.seed(seedValue)

################################################################################
############################## Defined Functions ###############################
################################################################################
# Function to Generate Small World Graph
MakeSWPNetwork <- function(dimension,size,nei,p){
  swpGraph <- watts.strogatz.game(dimension,size,nei,p, loops = FALSE, multiple = FALSE)
  return(swpGraph)
}

# Function to Generate an Erdos-Renyi random graph
MakeRandNetwork <- function(nodeCount, edgeCount){
  # Try to make a random graph with the watts.strogatz.game function
#  randGraph <- watts.strogatz.game(dimension,size,nei,1,loops = FALSE, multiple = FALSE)
  randGraph <- erdos.renyi.game(nodeCount, edgeCount, type="gnm",
                               directed = FALSE, loops = FALSE)
  return(randGraph)
}

MakeClusterGraph <- function(dim, size, nei, p, n, d){

  # Initial Swp Graph to make cumulative Swp
  G <- watts.strogatz.game(dim, size, nei, p)

  print("Initial G generation")
  print(paste("G nodes: ", vcount(G),"   G edges: ", ecount(G)))

  for (i in seq(from=1, to=(n - 1), by=1)){
    g <- watts.strogatz.game(dim, size, nei, p)

    G <- G + g

    print("G after addition")
    print(paste("G nodes: ", vcount(G),"   G edges: ", ecount(G)))
  }

  # connect components
  gL <- vcount(g)

  # Connect all subgraphs to each other
  # each subgraph
  for(i in seq(from=1, to= n-1, by=1)){
    # Link to each proceding sub-graph
    

      # For each other subgraph connection
      for(j in seq(from=(i + 1), to= n, by=1)){
        for(k in seq(from= 1, to= d, by=1)){
          x <- sample( (((i-1)*gL)+1):(i*gL) ,1)
          y <- sample( (((j-1)*gL)+1):(j*gL) ,1)

          print(x)
          print(y)

          G[x,y] <- TRUE
        }
      }

  }


  # Connect each subgraph to first subgraph
  # for(i in seq(from=1, to=(n-1), by=1)){
  #   # for each d
  #   for(j in seq(from=1, to=d, by=1)){
  #     x <- sample(1:gL,1)
  #     y <- sample(((gL*i)+1):(gL*(i+1)),1)

  #     G[x,y] <- TRUE
  #   }

  # }


  return(G)
}

# Finds the hubs of a network.
FindHubs <- function(runCount, hubSTD, swpGraph){
  # Finds the klienburg centrality hubs
  # Based on the standard deviation of the mean of the hub score.

  # hub score for each node
  hubScore <- hub.score(swpGraph)
  
  h <- hubScore$vector
  
  hubThreshold  <- mean(h)+(hubSTD*(sd(h)))

  # Replaces all hubs with a score above the threshold with a 1, and other
  # verticies with a 0. This is a discrete hub list, as betweenness values are
  # lost.
  hubMatrix   <- replace(replace(h, h >= hubThreshold, 1), h < hubThreshold, 0)


  return(hubMatrix)
}

# Returns the number of hubs in the Matrix
HubCounts <- function(hubMatrix){
  count <- sum(hubMatrix == 1)
  return(count)
}


# Calculates S^WS for the network.
CalcSws <- function(swpGraph, randGraph){
  # Calculates clustering coefficients of swp and rand graphs
  # old
  swpGamma  <-  transitivity(swpGraph, type="global", vids=NULL, weights=NULL,
                            isolates="Nan")
  # New Clustering Coefficient Calc
  swpCC     <- transitivity(swpGraph, type='localaverageundirecte', vids=NULL,
                            weights=NULL, isolates="NaN")
  
  # old								
  randGamma <- transitivity(randGraph, type="global", vids=NULL, weights=NULL,
                            isolates="Nan")                         

  # New Clustering Coefficient Calc
  randCC    <- transitivity(randGraph, type='localaverageundirected', vids=NULL,
                            weights=NULL, isolates="NaN")

  gamma     <- (swpGamma/randGamma) # combines them to get the Gamma value.
  gamma2    <- (swpCC/randCC) # Gamma w/ new CC calcs

  # Calculates the mean minmal path length for swp and corresponding rand graphs
  swpLambda <- average.path.length(swpGraph)
  randLambda <- average.path.length(randGraph)
  lambda <- (swpLambda / randLambda)  # Combines to get the ratio Lambda value

  Sws       <- (gamma/lambda) # Calculates S^WS from the ratio.
  Sws2      <- (gamma2/lambda) # Sws with new CC calculation
  
  swsList <- list("Sws" = Sws, "swpPathLength" = swpLambda, 
                  "swpClustering" = swpGamma, "swpCC" = swpCC, "Sws2"=Sws2)
  return(swsList)
}

# Returns two lists containing all the hub-hub connections.
HubHub <- function(swpGraph, hubs){
  hubhub1 <- c()
  hubhub2 <- c()

  for(hubN in hubs){
    adjHubs <- intersect(unlist(get.adjlist(swpGraph)[hubN]), hubs)
    if(length(adjHubs) > 0){
      for( m in seq(from=1, to=length(adjHubs), by=1)){
        hubhub1 <- c(hubhub1, hubN)
        hubhub2 <- c(hubhub2, adjHubs[m])
      }
    }
  }

  hubhub <- list("hubhub1" = hubhub1, "hubhub2"=hubhub2)
  return(hubhub)
}

################################################################################
##############################  Models Functions  ##############################
################################################################################

# Run model that attacks the hubs first.
Run_Hubs_Model <- function(runCount, swpGraph, randGraph, hubSTD, 
                           timeSteps){
  
  # Initialzie Model Print Out files
  # Graph Attributes
  runLogOutput = paste('run',runCount,'_logOutput.txt', sep="")
  write(paste('step \t hubCount \t Sws \t avg_Path_Length \t Transitivity \t Clustering \t Sws2 '), 
        file= runLogOutput, append = TRUE, sep=",")

  degreeOutput = paste('run',runCount,'_DegreeLog.txt', sep="")

  degreeMax <- 0  # set window max for plotting degree distribution
  probMax   <- 0

 # Returns a list of the vertex number of all the hubs. 
  for(step in seq(from=1, to=timeSteps, by=1)){
    # Swp Hubs
    swpHubMatrix  <- FindHubs(runCount, hubSTD, swpGraph)
    swpHubInd     <- (which(swpHubMatrix %in% 1))
    swpNonHubs    <- which(!(1:length(swpHubMatrix) %in% swpHubInd))

print(vcount(swpGraph))
print(ecount(swpGraph))
print(swpHubInd)    
    # SWP hub-hub connections
    hubhub  <- HubHub(swpGraph, swpHubInd)
    hubhub1 <- hubhub$hubhub1  # used for x
    hubhub2 <- hubhub$hubhub2  # used for y
   
print(paste('step: ', step))
    if(length(swpHubInd) < 1){
      print("terminate")
      #terminate 

    }else{
      # If there are hub-hub connections
      if(length(hubhub1) >= 2){
        # Takes a sample x from the list of connected hubs.
        xInd <- sample(1:length(hubhub1), 1) # Ind of a hub-hub connection
        x    <- hubhub1[xInd]                # node x for that connection
        y    <- hubhub2[xInd]                # node y for that connection
 
        swpGraph[x,y]    <- FALSE   # Removes edge between x and y
        nonAdjZ <- which(!(1:vcount(swpGraph) %in% unlist(get.adjlist(swpGraph)[x])))
        z  <- sample( intersect(swpNonHubs,nonAdjZ) , 1 ) 
        swpGraph[x,z] <- 1             # Adds edge between x and z
    
      }
      # If there are hubs, but no hub-hub connections
      else if( length(hubhub1) < 2 ){
        # If there is only 1 hub.
        if( length(swpHubInd) == 1){
          print("hub1")
          x <- swpHubInd[1]       # Select the hub
          y <- sample(unlist(get.adjlist(swpGraph)[x]), 1) # Random x-adj
          swpGraph[x,y] <- FALSE  # Removes edge between x and y
          nonAdjZ <- which(!(1:vcount(swpGraph) %in% unlist(get.adjlist(swpGraph)[x])))
          z <- sample( intersect(swpNonHubs,nonAdjZ), 1)
          swpGraph[x,z] <-1
        }else{ # If there is more than 1 hub
          x <- sample(swpHubInd, 1)   # Random hub node
          y <- sample(unlist(get.adjlist(swpGraph)[x]) , 1) # Random x-adj, non-hub    
          
          swpGraph[x,y] <- FALSE #Removes edge between x and y
          nonAdjZ <- which(!(1:vcount(swpGraph) %in% unlist(get.adjlist(swpGraph)[x])))
          z  <- sample( intersect(swpNonHubs,nonAdjZ) , 1 ) 
          swpGraph[x,z] <- 1            # Adds edge between x and z
        }
      }
    }

    # Checks to see if new degreeMax
    d  <- degree(swpGraph)
    dd <- degree.distribution(swpGraph)
    if(max(d) > degreeMax){
      degreeMax <- max(d)
    }
    if(max(dd) > probMax){
      probMax <- max(dd)
    }
    


    # Print attributes to output file
    # -------------------------------
    swsList <- CalcSws(swpGraph,randGraph)
    swpGamma  <-  transitivity(swpGraph, type="global", vids=NULL, weights=NULL)
    write(paste(step,'\t',HubCounts(FindHubs(runCount, hubSTD, swpGraph)),
          '\t', swsList$Sws,'\t', swsList$swpPathLength,'\t',
          swsList$swpClustering,'\t', swsList$swpCC, '\t', swsList$Sws2 ),
          file= runLogOutput, append = TRUE, sep="," )

    # Print Degree Data
    PrintDegree(swpGraph, runCount, step)
    # Print Degree Distrribution Data
    PrintDegreeDist(swpGraph, runCount, step, timeSteps, degreeMax, probMax)

    }
}
################################################################################
############################## Printing Functions ##############################
################################################################################
PrintGraphStats <- function(runCount, swpGraph, randGraph, hubMatrix,dimension, size,
                            nei, p, hubSTD){
  # Generate output file of each run in each run directory
  outfileName = "../cumulative_attributes.txt"   
    
  for (i in seq(from=1, to=2, by=1)){
    write(paste('runCount: ', runCount), file= outfileName, append = TRUE, sep= ", ")
    write(paste('seedVale: ', seedValue), file= outfileName, append = TRUE, sep=",")
    write(paste('dimension: ', dimension), file= outfileName, append = TRUE, sep= ", ")
    write(paste('Size: ',size), file= outfileName, append = TRUE, sep= ", ")
    write(paste('Nei: ', nei), file= outfileName, append = TRUE, sep= ", ")
    write(paste('p: ',p), file= outfileName, append = TRUE, sep= ", ")
    write(paste('hubSTD: ', hubSTD), file= outfileName,
          append = TRUE, sep= ", ")
    write(paste('swpGraph Vertice count: ', vcount(swpGraph)), file= outfileName,
          append = TRUE, sep= ", ")
    write(paste('swpGraph Edge count: ',ecount(swpGraph)), file= outfileName, 
          append = TRUE, sep= ", ")
    write(paste('swpGraph Sws: ', CalcSws(swpGraph, randGraph)$Sws), file= outfileName, append = TRUE, 
          sep= ", ")
    write(paste('swpGraph Hub count: ', sum(hubMatrix == 1)), file= outfileName,
          append = TRUE, sep= ", ")
    write('', file= outfileName, append = TRUE)
    
    outfileName <- paste('starting_params.txt', sep="")
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

# Plots out the node degrees of a graph at each step.
PrintDegree <- function(swpGraph, runCount, step){
  # Change to DegreeData folder
  setwd('DegreeData')

  # Make degree Matrix
  d <- degree(swpGraph)

  # Write to file
  degreeOutput = paste('run',runCount,'_DegreeLog.txt', sep="")
  cat(d, fill= 3*length(d), file=degreeOutput, sep=",", append = TRUE)

  setwd('..')   # Jump out of folder
}



# Plots out the degree distribution each step.
PrintDegreeDist <- function(swpGraph, runCount, step, timeSteps, degreeMax,
                            probMax){
  # Initialize data Folder
  folder = paste('run_',runCount, 'degreeDistData', sep = "" )

  # Change to Degree Distribution dir
  setwd('DegreeData')
  
  # If a sub-directory does not exit for current run, make it.
  system(paste('mkdir -p ', folder, sep = "" ))
  setwd(folder)     # Set working Directory to the Degree Run
  
  # Generate degree distribution matrix
  d <- degree.distribution(swpGraph)

  # Write to file
  degreeDistOutput = paste('run',runCount,'_step', step,'_DegreeDist.dat', sep="")
  for(i in seq(from=1, to= length(d), by=1)){
    write(paste(i,'\t',d[i]), file = degreeDistOutput, append = TRUE)
  }

  # If last step
  if(step == timeSteps){
    write(paste(degreeMax,"\n", probMax), sep="\n", file = "windowInfo.txt")
  }


  setwd('../..')    # Back out of degree run directory

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
hubSTD <- as.numeric(args[7]) # The standard deviations away from the mean for 
                              # determing a hub

# Number of runs
trialCount <- as.numeric(args[8])
timeSteps  <- as.numeric(args[9])

# Params for Clustering Graphs
n <- 10  # Number of Sub Graphs
d <- 2   # Number of edges to connect each sub-graph

setwd(topFolder)


# Generate Directories for all trials
runCount <- 1

for( i in seq(from=1, to= trialCount, by=1)){

  print(getwd()) # print current working directory
  
  print(paste('mkdir ',name, sep=""))
  system(paste('mkdir ', name, sep=""))
  setwd(paste(name, sep=""))

  system('mkdir DegreeData')

  print(getwd())

  #-----------------------------------------------
  #--------------- Model Sequence ----------------
  #-----------------------------------------------

  # Generate Graphs
  # ----------------
  notSWP      <- TRUE # true if the graphs are not swp
  notSWPCount <- 0
  while(notSWP){
    print("redo")
    notSWPCount <- notSWPCount + 1
    print(notSWPCount)

    swpGraph  <- MakeClusterGraph(dimension, size, nei, p, n, d)
    #swpGraph  <- MakeSWPNetwork(dimension,size,nei,p)
    randGraph <- MakeRandNetwork(vcount(swpGraph), ecount(swpGraph))


    if(CalcSws(swpGraph, randGraph)$Sws > 1) notSWP <- FALSE
    if(notSWPCount >= 1000){
	    write(paste('Could not generate SWP graph in ', notSWPCount, 
	  	            ' tries.'), file= 'failed.txt', append = TRUE, sep= ", ")
	    quit(save = "no")
      }
    }    
    
    # Run functions on Graphs
    # ------------------------
    hubMatrix <- FindHubs(runCount, hubSTD, swpGraph)
   # CalcSws = CalcSws(swpGraph, randGraph)
    PrintGraphStats(runCount, swpGraph, randGraph, hubMatrix, dimension, size, nei, p,
                    hubSTD)

    hubs_Model_run <- Run_Hubs_Model(runCount, swpGraph, randGraph, hubSTD, 
                           timeSteps)



    # Increment for next run
    # ----------------------
    runCount <- runCount + 1

    # Make directory for degree printouts, and move them there
    if(runCount >= trialCount){
      system('mkdir DegreeLogs')
      system('mv *_DegreeLog.txt DegreeLogs')
    }

    setwd("..") # Go up a directory
}




print(warnings())
