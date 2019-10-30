globals [theta turtle-select a0 time-events i cum-val turtle-list pSS pSI pS0 pII pI0 p00 total-patches total-pairs xI]
; theta: a parameter related to lattice geometry. Theta = 1/4 for a 2D lattice
; a0: the sum of rates accross all turtles, used to select a turtle
; turtle-select: the turtle randomly selected
; time-events: keeps track of the time of events
; i: just an internal counter, but the section of code I was working in was
; giving an error if the scope was not set to global
; cum-val: is used to randomly select a turtle that experiences the randomly selected event
; turtle-list: an agent-set of all turtles at a given time
; pij: the frequency of site pairs where one sight is occupied by i and one by j
; total-patches: the total number of patches in the landscape
; total-pairs: the total pairs counted on the landscape
; xI: total number of infecteds

; There are two breeds: susceptible (white) and infected (red)
breed [susceptibles susceptible] ; sheep is its own plural, so we use "a-sheep" as the singular.
breed [infecteds infected]

; turtles-own are properties specific to each turtle
turtles-own [neigh-S neigh-I neigh-0 cum-reprod cum-natmort cum-locinfect cum-globinfect cum-dismort bm turtlesum-r2]
; neigh-S: the number of susceptibles in the neighbourhood of a given turtle
; neigh-I: the number of infecteds in the neighbourhood of a given turtle
; neigh-0: the number of empty patches in the neighbourhood of a given turtle
; cum-natmort: the rate of natural mortality
; cum-reprod: cum-natmort + the rate of reproduction for a susceptible
; cum-locinfect: cum-reprod + the rate of local infection for a susceptible
; cum-dismort: cum-natmort + the rate of disease-induced mortality for an infected
; bm: the sum of all the rates for one turtle
; turtlesum-r2: cumulative sum-rates minus a random variable, used to select a random turtle

; patches-own are properties specific to each patch
patches-own [p-neigh-S p-neigh-I p-neigh-0]

;;;;;;;;;;;;;;;;; SETUP
; This routine set-up all the initial conditions
to setup
  clear-all
  set total-patches (max-pxcor - min-pxcor)*(max-pycor - min-pycor)
  set time-events 0 ; the initial value of time-events: start time at t=0.
  set theta 0.25 ; this corresponds to 1/z neighbours - it's an assumption about the lattice geometry
    ask patches [ set pcolor green ]
  set-default-shape turtles "sheep" ; so when new turtles are born they have the right shape
  create-susceptibles 20000  ; create the susceptible sheep
[
    set color white
    set size 1
    setxy random-xcor random-ycor
    ]
  create-infecteds 200 ; create the infected sheep
[
    set color red
    set size 1
    setxy random-xcor random-ycor
  ]
  ; This command is necessary to ensure only one turtle per patch on the set-up,
  ; however it does mean that the number of turtles created on each set-up is variable.
  ask turtles [ ask other turtles-here [ die ] ]
  reset-ticks
end

;;;;;;;;;;;; GO
; This routine is repeatedly executed after GO is pressed
to go
  ; conditions to stop the simulation
  if  count turtles  = 0 [ stop ]
  if time-events > tend [stop]
  ; calculate the rates for all events that can occur for all individuals in the population
  calc-rates
  ; calculate the frequency of pairs as the output variable
  freq-pairs
  ; choose the turtle that will have the event
  choose-turtle
  ; choose the event the turtle will have
  select-event
  ; update the time counter
  let r1 random-float 1
   set time-events  time-events -  ln(r1) / a0
  tick
end

; CALC-RATES
; This routine calculates the rates used to evaluate equations (5) and (6)
; of ABMs and Math Workshop.pdf
to calc-rates
  ; Rates depend on the status of neighbours.
  ; neigh-S is a turtles-own property describing the number of S neighbours
  ask turtles [set neigh-S count susceptibles-on neighbors4]
  ask turtles [set neigh-I count infecteds-on neighbors4]
  ask turtles [set neigh-0 count neighbors4 with [not any? turtles-here]]
  ; Below we calculate the cumulative rates for all susceptible individuals
  ask susceptibles [
    ; natural mortality
    set cum-natmort d
    ; reproduction
    set cum-reprod cum-natmort + (r / 4) * neigh-0
    ; local infection
    set cum-locinfect cum-reprod +  (1 - P)*(beta / 4) * neigh-I
    set cum-globinfect cum-locinfect +  P * xI * (beta / 4)
    ; bm is the sum of all rates. This is also equal to the last event in the
    ; cumulative sum. This is b_m in equation (5) of ABMs and Math Workshop.pdf
    set bm cum-globinfect
  ]
  ; Below we calculate the rates for infecteds (note that infecteds can have different events)
  ask infecteds [
    ; natural mortality
   set cum-natmort d
    ; disease-induced mortality
    set cum-dismort cum-natmort + alpha
    ; sum-rates is b_m in equation (5)
    set bm cum-dismort
  ]
end

; FREQ-PAIRS
; this routine calculates the frequency of paired sites
to freq-pairs
  let empty-patches patches with [not any? turtles-here]
  ask empty-patches [set p-neigh-0 count neighbors4 with [not any? turtles-here]]
  let cSS sum [neigh-S] of susceptibles
  let cSI sum [neigh-I] of susceptibles
  let cS0 sum [neigh-0] of susceptibles
  let cII sum [neigh-I] of infecteds
  let cI0 sum [neigh-0] of infecteds
  let c00 sum [p-neigh-0] of empty-patches
  set total-pairs cSS + 2 * cSI + 2 * cS0 + cII + 2 * cI0 + c00
  set pSS cSS / total-pairs
  set pSI 2 * cSI / total-pairs
  set pS0 2 * cS0 / total-pairs
  set pII cII / total-pairs
  set pI0 2 * cI0 / total-pairs
  set p00 c00 / total-pairs
  set xI cII + cI0 + cSI
end

; CHOOSE-TURTLE
  ; this function evaluates equation (5) of ABMs and Math Workshop.pdf to randomly select
  ; the turtle which an event happens to.
to choose-turtle
  ; a0 in equation (5) is the sum of bm across all turtles
  set a0 sum [bm] of turtles
  ; turtle-list is a list of all the turtles. This is so we can run a loop
  ; going through each turtle sequentially
  set turtle-list [who] of turtle-set turtles
  ; r2 as per equation (5)
  let a0r2 random-float a0
  ; the middle term of equation (5) is a cumulative sum of the bm values
  ; cum-val starts at 0.
  set cum-val 0
  ; to run the loop we start with i = 0 and will increment as the loop runs.
  set i 0
  ; a regular for loop is implemented as a while condition and incrementing the i counter
  while [i < count turtles] [
    ; In Netlogo the first item of a list is item 0. Also note that some turtles will die
    ; and so the turtle id numbers are not just a run of consecutive integers
  ask turtle (item i turtle-list) [
      ; each turtle is assigned an interval of the number line of a length in proportion
      ; to its bm value (i.e., the cumulative sum). a0r2 is subtracted to help with the
      ; evaluation of equation (5)
      set turtlesum-r2 cum-val + bm - a0r2
    ]
    ; update the cumulative bm value
      set cum-val cum-val + [bm] of turtle (item i turtle-list)
    ; increment i by 1 to move on to the next turtle on the next iteration
      set i i + 1
  ]
  ; To evaluate equation (5) we find the set of all turtles with positive values
  ; of turtlesum-r2
  let subset-of-turtles turtles with [ turtlesum-r2 > 0 ]
  ; Evaluation of equation (5) is completed by selecting the turtle with the smallest
  ; positive value of turtlesum-r2. The turtle-select is l = l_i
  set turtle-select subset-of-turtles with-min [turtlesum-r2]
end

; SELECT-EVENT
  ; This routine evaluates equation (6) to identify which event happens of all the
  ; possible events of the selected turtle "turtle-select".
to select-event
  ; Note: when I do the commands to ask for turtles-own properties of turtle-select
  ; I get lists with length 1, so I had to write item 0 to get a scalar that I could
  ; use for other commands
  ; b_l is the bm value of turtle select.
  let b_l [bm] of turtle-select
  ; blr3 is b_l * r3.
  let blr3 random-float item 0 b_l
  ; j is a switch so that when j = 1 no more conditions are evaluated
  let j 0
  ; The events can be different depending on whether turtle-select is an infected or
  ; susceptible individual
  ifelse item 0 [breed] of turtle-select  = susceptibles [
    ; cycle through the possible events: the first is natural mortality
    if blr3 < item 0 [cum-natmort] of turtle-select
    ; implement the event corresponding to natural mortality
    [ask turtle-select [die]
    set j 1]
    ; The if cause can't be evaluated if turtle-select dies, so need to first
    ; evaluate j < 1.
    if j < 1 [
      ; The next possible event is reproduction
    if blr3 < item 0 [cum-reprod] of turtle-select
      ; this is the event corresponding to reproduction. We require that reproduction
      ; occurs into an empty patch
      [ask turtle-select [hatch 1 [let free-neighbor one-of neighbors4 with [not any? turtles-here]
        move-to free-neighbor] ]
    set j 1]
      ; The next possible event is infection
    if blr3 < item 0 [cum-globinfect] of turtle-select and j < 1
      ; if infection occurs the turtle changes breed
      [ask turtle-select [set breed infecteds]
        ask turtle-select [set color red]
    set j 1]
    ]
  ]
  ; this is the other part of the ifelse if turtle-select is an infected
  [ ask turtle-select [die] ; the only options are to die of disease-induced mortality or naturally -
  ; either way, if turtle-select is an infected, the outcome is mortality
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
355
10
873
529
-1
-1
10.0
1
14
1
1
1
0
1
1
1
-25
25
-25
25
1
1
1
ticks
30.0

BUTTON
15
20
84
53
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
95
20
170
53
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
20
165
345
305
freq of patch types
iteration
freq
0.0
100.0
0.0
1.0
true
true
"" ""
PENS
"pI" 1.0 0 -2674135 true "" "plot pII + pSI + pI0"
"pS" 1.0 0 -16449023 true "" "plot pSS + pSI + pS0"
"p0" 1.0 0 -10899396 true "" "plot pS0 + pI0 + p00"

INPUTBOX
5
70
55
130
r
4.0
1
0
Number

INPUTBOX
125
70
175
130
beta
4.0
1
0
Number

INPUTBOX
180
70
235
130
alpha
0.0
1
0
Number

PLOT
10
340
345
460
time (years)
iteration
time
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"time of events" 1.0 0 -7500403 true "" "plot time-events"

INPUTBOX
60
70
115
130
d
1.0
1
0
Number

INPUTBOX
240
70
295
130
P
1.0
1
0
Number

INPUTBOX
240
10
295
70
tend
10.0
1
0
Number

@#$#@#$#@
# IBM with local reproduction and infection spread

This is an individual-based model for disease dynamics where infections may spread locally, with probability 1-P, or globally, with probability P. When infections occur locally, infection can only be spread from an infected individual to a susceptible neighbour, but when infections occur globally, an infected individual can infect any susceptible individual regardless of their location.

The simulation assumes that only susceptible hosts can reproduce, and that reproduction is local, such that there must be a neighbouring unoccupied site for the offspring to occupy. Both susceptible and infected individuals experience background mortality at rate, d.

The default parameter are set so the infection is avirulent (no disease-induced mortality, alpha = 0), but the disease is sterilizing (since infecteds can not reproduce).  The disease dynamics follow an SI formulation, which means that infected individuals do not recover. 

Parameters:
tend: the length of the simulation
r: reproduction rate
d: natural mortality rate
beta: transmission rate
alpha: diseaser-induced mortality rate
P: probability of global infection spread

Many more details of the model formulation can be found in the reference for a closely related model.

## Instructions
1. Choose parameter values.
2. Press the SETUP button.
3. Press the GO button to begin the simulation.
4. Press the GO button again to stop (although the simulation also has breaks coded for extinction and after a fixed amount of time).


## References
Hurford, A., J. Watmough, J. Marino, A. Mcleod, C. Prokopenko. Agent-based models and the mathematical equations that describe them. https://github.com/jameswatmough/CSEE2019-AARMS-ABM-workshop/blob/master/Documentation/ABM-Workshop-CSEE2019.pdf
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
set model-version "sheep-wolves-grass"
set show-energy? false
setup
repeat 75 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>xI</metric>
    <metric>xS</metric>
    <metric>time-events</metric>
    <enumeratedValueSet variable="r">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
