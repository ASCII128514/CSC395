using LinearAlgebra
using Plots
using DelimitedFiles
using LightGraphs
using StatsBase
using Distributions
using GraphPlot

# Create a network that have 98 nodes, represents the "spaces" of a shopping mall
G = Graph(98)
# A public space connecting to all cluster and offsite
node_labels=["public Space"];

# node 2-7 will be restaurant cluster, each is connect to the public space
for i in 2:7
    add_edge!(G, 1, i)
end

# node 32-39 will be retail store cluster, each is connect to the public space
for i in 32:39
    add_edge!(G,1,i)
end

# node 80 will be movie theater cluster, connect to the public space
add_edge!(G,1,80)

#node 93 will be gym cluster, 
add_edge!(G,1,93)

#node 98 will be offsite from shopping mall, connect to the public space
add_edge!(G,1,98)

# for each restaurant cluster there will be edges connection to 4 different restaurants 
for i in 1:6
    for j in 1:4
        add_edge!(G, i+1, 4*i-4+j+7)
    end
end

# for each retail store cluster there will be edges connection to 5 different retail stores 
for i in 1:8
    for j in 1:5
        add_edge!(G, i+31, 5*i-5+j+39)
    end
end

# movie theater cluster will have edges to connect to 12 other show rooms
for i in 1:1
    for j in 1:12
        add_edge!(G, i+79, 12*i-12+j+80)
    end
end

# gym cluster will have edges to connect to 4 gym rooms
for i in 1:1
    for j in 1:4
        add_edge!(G, i+92, 4*i-4+j+93)
    end
end


#Set riskmultiplier based on the location
riskmulti=[1]
#Set the compacity of each place
compacity=[2000]
# Adding appropriate label for each nodes
for i in 2:7
    push!(node_labels,"restaurant cluster")
    push!(riskmulti, 3)
    push!(compacity, 200)
end

for i in 8:31
    push!(node_labels, "restaurant $(i-7)")
    push!(riskmulti, 3)
    push!(compacity, 120)
end

for i in 32:39
    push!(node_labels, "retail store cluster")
    push!(riskmulti, 1)
    push!(compacity, 300)
end

for i in 40:79
    push!(node_labels, "retail store $(i-39)")
    push!(riskmulti, 1)
    push!(compacity, 150)
end

push!(node_labels, "cinema cluster")
push!(riskmulti, 2)
push!(compacity, 500)
for i in 81:92
    push!(node_labels, "cinema room $(i-80)")
    push!(riskmulti, 2)
    push!(compacity, 100)
end

push!(node_labels, "gym cluster")
push!(riskmulti, 3)
push!(compacity, 200)

for i in 94:97
    push!(node_labels, "gym room $(i-93)")
    push!(riskmulti, 3)
    push!(compacity, 100)
end

push!(node_labels, "Home")
push!(riskmulti, 0)
push!(compacity, 100000);

# Plot the network
p = gplot(G, nodelabel=node_labels, NODELABELSIZE=1)

#= ---------------------Simulation-------------------------- =#

# Constructor for the agents in the simulation
mutable struct Person
    isInfected
    isEmployee
    hadMeal
    exposed
    isBackHome
    isWatchingMovie
    #An array that contains the location where the agent will be at (From 10am to 9pm)
    schedule 
    #An array that contains the true/false for each intervention(by index) that agent follows
    #1.Social distance, 2.mask, 3.temperature measurement, 
    # limit the number of people in a place(this will be controlled by the inputs for simulation)
    intervention     
    
end

#= 
procedure:
    generateScheduleCustomer
purpose:
    Generate a schedule for agents who are customers
parameter:
    person, Person(mutable structure); temperature, a boolean 
produces:
    (void)person, Person(mutable structure)
precodition:
    person must have all other fields set except schedule; 
    temperature must be true if the person is person.intervention[3] is true, otherwise false
postcondition: 
    person will have a schedule set, where length(person.schedule) == 12, elements in the schedule will be integers 
    from 1-98
=#
function generateScheduleCustomer(person,temperature)
    #If temperature ==true and person has been exposed to COVID19 for more than 13 days
    if temperature && person.exposed>=14
        #person will not be allowed to enter the shopping mall
        person.schedule=fill(98,12)
        return
    end
    # Set schedule back to empty
    person.schedule=[]
    # The process will repeat for 12 times
    for i in 10:21
        # If the person is still at the shopping mall
        if(!person.isBackHome)
            # If the person is not an employee
            if(!person.isEmployee)
                #If the person is already watching a movie then they will stay at same location for another hour
                if(person.isWatchingMovie)
                    push!(person.schedule,person.schedule[length(person.schedule)])
                    # After two hours, person has finish watching the movie
                    person.isWatchingMovie=false
                    continue
                end
                #Person will pick a restaurant for food if they haven't eat after 17:00
                if(i>17 && !person.hadMeal)
                    push!(person.schedule, rand(40:79))
                    person.hadMeal=true
                end
                # Choose a place to go to 
                place=rand(1:98)
                #If the person already had a meal they will not eat another meal
                if (person.hadMeal)
                        place=rand(1:98)
                        while(place >= 8 && place <= 31)
                            place=rand(1:98)
                        end
                end
                # If the place is a restaurant, person will had a meal
                if(place >= 8 && place <= 31)
                        person.hadMeal=true
                end
                # If the place is a showing room, then the person will be watching movie
                if(place >= 81 && place <= 92)
                    person.isWatchingMovie=true
                end
                # Add the location to person's schedule
                push!(person.schedule,place)
            end
        else
            # If the person is at home they will stay home
            push!(person.schedule,98)
        end
    end
end

#=
procedure: 
    generateScheduleEmployee
purpose: 
    Generate a schedule for agents who are employees
parameter: 
    person, Person(mutable structure)
    temperature, a boolean
produce: 
    (void)person, Person(mutable structure)   
precondition:
    person must have all other fields set except schedule; 
    temperature must be true if the person is person.intervention[3] is true, otherwise false
postcondition: 
    person will have a schedule set, where length(person.schedule) == 12, elements in the schedule will be integers 
    from 1-98, 5 elements in the schedule will be 98, most of the other elements in the schedule will be the same
    integer
=#
function generateScheduleEmployee(person,temperature)
    #If shopping mall is doing temperature measuring and person has been exposed to COVID19 for more than 13 days
    if temperature && person.exposed>=14
        #person will not be allowed to enter the shopping mall
        person.schedule=fill(98,12)
        return
    end
    # Assign work location
    workposition=rand(1:97)
    # Assign start time for work
    startingTime = rand(10:14)
    #work hour set to 0
    workhour=0
    #Set schedule to be empty
    person.schedule=[]
    
    # Before working hour, person will not be in the mall
    if(startingTime>10)
        for i in 10:startingTime-1
            push!(person.schedule, 98)
        end
    end
    # When person start working
    for i in startingTime:21
        # If they've work for 7 hours then they will go home
        if workhour == 7
            push!(person.schedule, 98)
        else
            # Each time slot have 10% chance to be the person's free time
            freetime=rand(1:10)
            if freetime==10 && !person.hadMeal
                # person will pick a resturant to eat during their free time, if they haven't had their free time
                push!(person.schedule, rand(8:31))
                person.hadMeal=true
            else
                # person will stay in their workposition during their work hour
                push!(person.schedule, workposition)
                workhour+=1
            end
        end
    end
end


#=
procedure: 
    generateEmployeeAndCustomer
purpose: 
    Generate e number of employee and c number of customers, with intervention based on p and intervarr
parameter: 
    e, an integer 
    c, an integer
    p, an float
    intervarr, an array
produce: 
    res, an array of Person, where the first e number of elements are "employee" and the rest are "customers"
    0<p<1; length(intervarr)==3
preconditions:
    length(res)== e+c; length of interventions for each elements in result is equal to length(intervarr); 
    if an element is false in the intervarr, then at the same index in the interventions for each elements 
    in result is also false
=#
function generateEmployeeAndCustomer(e,c,p,intervarr)
    #initialze res to be an array
    res=[] 
    for i in 1:e
        #each employee have 0.05% chance of already been infected by COVID-19
        isInfected = rand(1:10000)<6
        #if they are already indected then they've exposed to either 3-20 days, otherwise 
        #they've not been exposed and expose will be set to 1
        expose = isInfected ? rand(3:20) : 1
        #creating the employee, and set interventions based on intervarr, if intervarr[i] is false, then the corresponding 
        #index will also be false, otherwise, the corresponding index will be true only if p is greater than the random 
        #float generated 
        employee=Person(isInfected,true,false,expose,false,false,[],map((x)-> x ? p > rand(Float64) : false,intervarr))
        #add the employee into the result
        push!(res,employee)
    end
    for i in 1:c
        #each customer have 0.05% chance of already been infected by COVID-19
        isInfected = rand(1:10000)<6
        #if they are already indected then they've exposed to either 3-20 days, otherwise 
        #they've not been exposed and expose will be set to 1
        expose = isInfected ? rand(3:20) : 1
        #creating the customer, and set interventions based on intervarr, if intervarr[i] is false, then the corresponding 
        #index will also be false, otherwise, the corresponding index will be true only if p is greater than the random 
        #float generated 
        customer=Person(isInfected,false,false,expose,false,false,[],map((x)-> x ? p > rand(Float64) : false,intervarr))
        #add the customer into the result
        push!(res,customer)
    end
    return res
end

#=
procedure:
    generateSchedule
purpose: 
    Generating schedule for agents
parameter: 
    people, an array of Person
    startpoint, an integer
    endpoint, an integer
    temperature, an boolean
produce: 
    people, elements in people from index startpoint to endpoint have new schedule (void)
=#
function generateSchedule(people, startpoint, endpoint, temperature)
    #If the starting point is a employee, then from startpoint to endpoint will all be employee, 
    # otherwise all customer
    isEmployee=people[startpoint].isEmployee
    for i in startpoint:endpoint
        # If the they are all employee then generate employee schedule for them, and pass in temperature
        if isEmployee
            generateScheduleEmployee(people[i],temperature)
        else
        # Otherwise they are all customer and generate customer for them, and pass in temperature
            generateScheduleCustomer(people[i],temperature)
        end
    end
end

#=
procedure:
    location!
purpose: 
    Generate a 2D array, where it contains the number of people at a location during a specific time of the day
parameter: 
    place, an 2D array
    people, an array of Person
    iteration, an integer
produce: 
    place, an 2D array
=#
function location!(places,people, iteration)
    i = 1
    #Reset each array in the place to be empty
    for p in places
        places[i]=[]
        i+=1
    end
    i=1
    #For each Person in people 
    for p in people
        # Assign each person with an integer(based on its index in people) and place it into the 2D array
        push!(places[p.schedule[iteration]], i)
        i+=1
    end
end

#=
procedure:
    hasCovid
purpose: 
    Find the number of infected people, who is able to infect others, at each location
parameter: 
    people, an array of Person
    place, a 2D array of integer
produce: 
    sum, an integer
=#
function hasCovid(people, place)
    # Set sum to be zero
    sum=0
    # For each integer(the index of the person) in place 
    for p in place
        # Get the corresponding person, and increment sum if the person is infected and wheter if they 
        #has been infected for more than 2 days (onces they are infected for more than 2 day, then they can 
        #infect others)
        if people[p].isInfected==true && people[p].exposed>2
            sum+=1
        end
    end
    return sum
end

#=
procedure:
    generatePeople
purpose: 
    Generate the array of person with all fields filled
parameter: 
    employeeNum, an integer
    customerNum, an integer
    p, an float
    arr, an array
produce: 
    people, an array
=#
function generatePeople(employeeNum,customerNum,p,arr)
    #Generating employeeNum number of employees and customerNum number of customers, with p and arr
    people=generateEmployeeAndCustomer(employeeNum,customerNum,p, arr)
    #Generate/update the schedule of first employeeNum number of person
    generateSchedule(people,1,employeeNum,arr[3])
    #GGenerate/update the schedule of customerNum number of person, after employeeNum
    generateSchedule(people,employeeNum+1,employeeNum+customerNum,arr[3])
    return people
end

#=
procedure:
    simulate
purpose:
    simulate the agent-base modeling using the parameters to see the daily infection number and total infection 
    number over 30 days
parameters:
    employeeNum, an integer
    customerNum, an integer
    prob, an float
    interventions, an array of boolean
produce:
    result, an 2D array
precondition:
    0<prob<1; length(interventions)==3;
postcondition:
    length(result[1])==30; length(result[2])==30
=#
function simulate(employeeNum,customerNum,prob,interventions)
    global places=[]
    for i in 1:98
        push!(places, [])
    end
    resDaily=[]
    resTotalInfection = []
    #Generate people with all fields filled 
    people=generatePeople(employeeNum,customerNum,prob,interventions)
    #Initialized totalInfection to as an array
    totalInfection = []
    #Set total to be 0
    total = 0
    #Initialized totalInfection to as an array
    daily=[]
    #For each of the 30 days
    for x in 1:30
        #Set dailyInfected to be 0
        dailyInfected = 0
        #For each of the 12 hours
        for i in 1:12
            #find where each person is located at time i
            location!(places,people,i)
            #Set v (vertex) to be 0
            vertex = 0
            #for each place array in places
            for place in places
                #Increament vertex number, which correspond to which place array in the places
                vertex+=1
                #Get the number of infected people at place
                infect = hasCovid(people, place)
                #If facemask intervention is asked
                if interventions[1] && interventions[2]
                    #Get number of infected people who are wearing facemask
                    numOfInfecPeoWearingMask=length(filter((p)->people[p].isInfected && people[p].exposed>2 && people[p].intervention[2], place))
                    #Get the infection probabilities
                    rate = riskmulti[vertex]*0.75*1.25*((infect-numOfInfecPeoWearingMask)+0.5*numOfInfecPeoWearingMask)/compacity[vertex]
                    #For each person at the place
                    for p in place
                        #Check whether one follows social distancing
                        r = people[p].intervention[1] ? 0.2*rate : rate
                        #If they are wearing facemask, then they will use the previous infection probabilities, otherwise they will be 1.333 more
                        #likely to be infected 
                        people[p].isInfected = people[p].isInfected || (people[p].intervention[2] ? rand(Float64)<r : 0.75*rand(Float64)<r) 
                    end
                elseif interventions[2]
                    #Get number of infected people who are wearing facemask
                    numOfInfecPeoWearingMask=length(filter((p)->people[p].isInfected && people[p].exposed>2 && people[p].intervention[2], place))
                    #Get the infection probabilities
                    rate = riskmulti[vertex]*0.75*1.25*((infect-numOfInfecPeoWearingMask)+0.5*numOfInfecPeoWearingMask)/compacity[vertex]
                    #For each person at the place
                    for p in place
                        #If they are wearing facemask, then they will use the previous infection probabilities, otherwise they will be 1.333 more
                        #likely to be infected 
                        people[p].isInfected = people[p].isInfected || (people[p].intervention[2] ? rand(Float64)<rate : 0.75*rand(Float64)<rate) 
                    end
                elseif interventions[1]
                    #Otherwise infection rate are not directly effected by the intervention
                    rate = riskmulti[vertex]*1.25*infect/compacity[vertex]
                    #For each person in place
                    for p in place
                        #Check whether one follows social distancing
                        r = people[p].intervention[1] ? 0.2*rate : rate
                        #If the person is not already infected, then the previous rate are used to determine if the
                        #person is infected or not
                        people[p].isInfected = people[p].isInfected || rand(Float64)<r
                    end
                else
                    #Otherwise infection rate are not directly effected by the intervention
                    rate = riskmulti[vertex]*1.25*infect/compacity[vertex]
                    #For each person in place
                    for p in place
                        #If the person is not already infected, then the previous rate are used to determine if the
                        #person is infected or not
                        people[p].isInfected = people[p].isInfected || rand(Float64)<rate
                    end
                end
            end
        end
        #For each of the employee
        for i in 1:employeeNum
            #If they are infected
            if people[i].isInfected
                #If it's the first day of the simulation and employee is already infected
                if x==1 && people[i].exposed !=1
                    #Increment the daily infected number
                    dailyInfected+=1
                end
                #increment their day of exposed
                people[i].exposed +=1
                #If it's after the first day, and employee is infected
                if people[i].exposed==2
                    #Increment the daily infected number
                    dailyInfected+=1
                end
            end
        end

        #For each of the customer
        for i in employeeNum+1:employeeNum+customerNum
            #If they are infected
            if people[i].isInfected
                #increment the daily infected number
                dailyInfected+=1
            end
            #Reset the customer before the next simulation day
            #0.05% chance of being infected
            isInfected = rand(1:10000)<6
            #Set expose to be 3-15 if infected, 1 if not infected
            expose = isInfected ? rand(3:20) : 1
            #Generate person with different fields, and set intervention
            people[i]=Person(isInfected,false,false,expose,false,false,[],map((x)-> x ? prob > rand(Float64) : false,interventions))
        end
        #Generate new schedule for all the new customers
        generateSchedule(people,employeeNum+1,employeeNum+customerNum,interventions[3])
        #Add dailyInfected to total number of infected people so far in the simulation
        total+=dailyInfected
        #append the total into totalInfection array
        push!(totalInfection, total)
        #append the dailyInfected into daily array
        push!(daily,dailyInfected)
    end
    #return the 2D array that contains both daily array and totalInfection array
    return [daily,totalInfection]
end

#=
procedure:
    simulateNtimes
purpose:
    simulate the agent-base modeling using the parameters to see the daily infection number and total infection 
    number over 30 days for n times to get the average
parameters:
    n, integer
    employeeNum, an integer
    customerNum, an integer
    prob, an float
    interventions, an array of boolean
produce:
    result, an 2D array
precondition:
    n>0; 0<prob<1; length(interventions)==3;
postcondition:
    length(result[1])==30; length(result[2])==30
=#

function simulateNtimes(n,employeeNum,customerNum,prob,interventions)
    daily=[]
    overall=[]
    for i in 1:n
        res = simulate(employeeNum,customerNum,prob,interventions)
        if i == 1
            daily = res[1]
            overall = res[2]
        else
            j = 1
            for val in res[1]
                daily[j]+=val
                j+=1
            end
            j=1
            for val in res[2]
                overall[j]+=val
                j+=1
            end
        end
    end
    return [daily./n,overall./n]
end

#=
procedure: 
    createGraph
purpose: 
    Generate and save a Graph based on the data parameter
parameter: 
    x, array
    y, array of arrays or array
    title, string
    label, array of string
    xlabel, string
    ylabel, string
    fn, string
produce: 
    (void)png file with the name fn
=#
function createGraph(x, y, title, label, xlabel, ylabel,fn)
    plot(x, y, title = title, label=label)
    xlabel!(xlabel)
    ylabel!(ylabel)
    png(fn) # save the current fig as png with filename fn
end


#=--------------------No intervention at all-----------------------=#

#Simulation variables:
#Set employee number to be 1000
employeeNum=1000
#9000 customer in the mall each day.
customerNum=9000

res = simulateNtimes(40, employeeNum,customerNum,1,[false,false,false])

daily = []
overall = []
push!(daily,res[1])
push!(overall, res[2])

#=--------------------Social distancing-----------------------=#

#Simulation variables:
#Set employee number to be 1000
employeeNum=1000
#9000 customer in the mall each day.
customerNum=9000

res = simulateNtimes(40, employeeNum,customerNum,1,[true,false,false])

push!(daily,res[1])
push!(overall, res[2]);


#= -----------------facial mask---------------------------------=#

#Simulation variables:
#Set employee number to be 1000
employeeNum=1000
#9000 customer in the mall each day.
customerNum=9000

res = simulateNtimes(40,employeeNum,customerNum,1,[false,true,false])

push!(daily,res[1])
push!(overall, res[2]);

#= -----------------------Temperature measurement-----------------------=#

#Simulation variables:
#Set employee number to be 1000
employeeNum=1000
#9000 customer in the mall each day.
customerNum=9000

res = simulateNtimes(40,employeeNum,customerNum,1,[false,false,true])
push!(daily,res[1])
push!(overall, res[2]);

#= ---------------------Limiting the number of people in the mall ------------=#

#Simulation variables:
#Set employee number to be 500
employeeNum=500
#4500 customer in the mall each day.
customerNum=4500

res = simulateNtimes(40,employeeNum,customerNum,1,[false,false,false])

push!(daily,res[1])
push!(overall, res[2]);

#= ---------------------Following Intervention 2,3,4--------------------=#
#Simulation variables:
#Set employee number to be 500
employeeNum=500
#4500 customer in the mall each day.
customerNum=4500

res = simulateNtimes(40,employeeNum,customerNum,1,[false,true,true])

push!(daily,res[1])
push!(overall, res[2]);

# Plot the graph
createGraph(1:30, daily, "Daily infection",
    ["no intervention" "social distancing" "facial mask" "temperature measurement" "limit number of costomers" "Intervention 2,3,4"],
    "time", 
    "daily infection",
    "Daily_Infection")


createGraph(1:30, overall, "Overall infection",
["no intervention" "social distancing" "facial mask" "temperature measurement" "limit number of costomers" "Intervention 2,3,4"],
"time", 
"Overall infection",
"Overall_Infection")


#= --------------------Percentage of people following the intervention/Infection----------------=#

#=----------------------Social distancing------------------------=#
overall_efficient = []
#For probabilities from 0 to 1, intervals of 0.1
for p in 1:11
    #Simulation variables:
    # 1000 employees
    employeeNum=1000
    # 9000 customer in the mall each day.
    customerNum=9000
    #Append the total infection number after 30 days into the overall array for each probabilites
    push!(overall_efficient,simulateNtimes(10,employeeNum,customerNum,(p-1)/10,[true,false,false])[2][30])
end

y = []
x = map((i)->"$((i-1)*10)%",1:11)
push!(y, overall_efficient)

#=-----------------------Facial mask--------------------=#
overall_efficient = []
#For probabilities from 0 to 1, intervals of 0.1
for p in 1:11
    #Simulation variables:
    # 1000 employees
    employeeNum=1000
    # 9000 customer in the mall each day.
    customerNum=9000
    #Append the total infection number after 30 days into the overall array for each probabilites
    push!(overall_efficient,simulateNtimes(10,employeeNum,customerNum,(p-1)/10,[false,true,false])[2][30])
end

push!(y, overall_efficient)

#= ----------------Following intervention 2,3,4--------------------=#

overall_efficient = []
#For probabilities from 0 to 1, intervals of 0.1
for p in 1:11
    #Simulation variables:
    # 500 employeeNum total
    employeeNum=500
    # 4500 customer in the mall each day.
    customerNum=4500

    #Append the total infection number after 30 days into the overall array for each probabilites
    push!(overall_efficient,simulateNtimes(10,employeeNum,customerNum,(p-1)/10,[false,true,true])[2][30])
end

push!(y, overall_efficient)

#= -------------------Following all intervention------------------=#
overall_efficient = []
#For probabilities from 0 to 1, intervals of 0.1
for p in 1:11
    #Simulation variables:
    # 500 employeeNum total
    employeeNum=500
    # 4500 customer in the mall each day.
    customerNum=4500

    #Append the total infection number after 30 days into the overall array for each probabilites
    push!(overall_efficient,simulateNtimes(10,employeeNum,customerNum,(p-1)/10,[true,true,true])[2][30])
end

push!(y, overall_efficient)


#=-----------Plot Graph-------------------=#
createGraph(map((i)->"$((i-1)*10)%",1:11), y, "Overall infection",
    ["social distancing" "facial mask" "intervention 2 3 4" "all intervention"],
    "time", 
    "Overall infection",
    "effectiveness_of_intervention")