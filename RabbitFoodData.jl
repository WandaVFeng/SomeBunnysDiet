# ==============================================================================
# Wanda Feng
# last updated: March 2021
#
# Rabbit Food Nutritional Data
#
# ==============================================================================

# Packages =====================================================================
using DataFrames, DataFramesMeta, CSV
using Unicode
using Statistics

# Start timer ==================================================================
#@time begin

# Directories ==================================================================
dirdata = "/Users/wandafeng/Desktop/Rabbit_Food_data/"
USDA_dirdata = dirdata*"FoodData_Central_csv_2020-10-30/"

# Read files ===================================================================
# USDA all data ----------------------------------------------------------------
#       downloaded from: https://fdc.nal.usda.gov/download-datasets.html
#   food names & IDs
file1 = USDA_dirdata*"food.csv"
USDA_Food = DataFrame(CSV.File(file1)) # 533612x5
#   portion weights (g) & equivalents
file2 = USDA_dirdata*"food_portion.csv"
USDA_PortionData = DataFrame(CSV.File(file2)) # 56893x11
#   nutrients by ID
file3 = USDA_dirdata*"food_nutrient.csv"
USDA_NutrientData = DataFrame(CSV.File(file3)) # 7547844x11

# Isolate relevant data types ==================================================
#   FNDDS, Foundation, & SR Legacy contain relevant veg & fruit data
###### may want to add Branded Foods in future - e.g. "Spring mix"
USDA_Food_ed = @where(USDA_Food,
    in(["survey_fndds_food","foundation_food","sr_legacy_food"]).(:data_type)) # 15053x5

# Tabulate portion weights for rabbit safe veg & fruit =========================
#   combine food names, USDA IDs, + portion data -------------------------------
USDA_Food_Portion = innerjoin(USDA_Food_ed,USDA_PortionData, on = :fdc_id) # 46402x15
#CSV.write(dirdata*"USDA_Food_Portion.csv", USDA_Food_Portion)
USDA_Food_Portion_gr = groupby(USDA_Food_Portion, :data_type)
#   isolate foods where portion = 1 cup ----------------------------------------
FNDDS_FP = @where(USDA_Food_Portion_gr[2], in(["1 cup"]).(:portion_description)) # 3305x15
Foundation_FP = @where(USDA_Food_Portion_gr[1], in([1000]).(:measure_unit_id)) # 51x15
SRlegacy_FP = @where(USDA_Food_Portion_gr[3], in(["cup","cup, chopped",
    "cup shredded","cup, shredded","cup sliced","cup, sliced",
    "cup sprigs"]).(:modifier)) # 1880x15
#   search for food item by data type
function FindItemData(food_item, db)
    println("============================================")
    println("Finding portion values for "*food_item*" in "*db.data_type[1])
    #   make string comparison case insensitive
    food_item = Unicode.normalize(food_item*",", casefold=true)
    for j = 1:length(db.description)
        db_item = Unicode.normalize(db.description[j], casefold=true)
        if occursin(food_item,db_item) == true #&&
            #endswith(db.description[j],"raw") == true
            println("--- description: "*db.description[j])
        end
    end
end

#=
#   isolate FNDDS veg & fruit --------------------------------------------------
food_cat_id_begin = zeros(length(FNDDS_FP.food_category_id))
for i=1:length(FNDDS_FP.food_category_id)
    if startswith(string(FNDDS_FP.food_category_id[i]),"6") == true
        #println("index = "*string(i)*"--------------------------------------------")
        #println(string(FNDDS_FP.food_category_id[i]))
        food_cat_id_begin[i] = 1
    end
end
FNDDS_FP = hcat(FNDDS_FP,food_cat_id_begin)
FNDDS_FP = @where(FNDDS_FP, in([1.0]).(:x1)) #713x16
select!(FNDDS_FP,Not(:x1)) #713x15
=#
#   combine ed data ------------------------------------------------------------
USDA_Food_Portion = vcat(FNDDS_FP,Foundation_FP,SRlegacy_FP)

#   Rabbit safe veg & fruit lists ----------------------------------------------
#       Leafy Greens; Herbs & Flowers; Non Leafy; Fruit
LG_list = ["Arugula","Beet greens","Cabbage, Chinese","Carrot greens","Chicory greens",
    "Collards","Dandelion greens","Endive","Escarole","Kale",
    "Boston","Green leaf","Red leaf","Romaine","Mustard greens",
    "Radicchio","Radish greens","Spinach","Chard","Turnip greens","Watercress"]
    # Chinese Cabbage = Bok Choy
H_list = ["Basil","Caraway","Chamomile","Cilantro","Clover",
    "Dill weed","Echinacea","Goldenseal","Kava","Lavender",
    "Lemon balm","Lemongrass","Marigolds","Marjoram","Peppermint",
    "Spearmint","Nasturtium","Nettle","Oregano","Pansy",
    "Parsley","Purslane","Rose","Rosemary","Sage",
    "Shepherd's purse","Tarragon","Thyme","Wheatgrass"]
### FILTER FOR TSP & TBSP
NL_list = ["Beets","Pepper, sweet, green","Pepper, sweet, red", "Broccoli","Brussels",
    "Cabbage, green","Cabbage, red","Carrots","Cauliflower","Celery",
    "Fennel","Summer squash, green","Summer squash, yellow","zucchini"]
F_list = ["Apple","Apricot","Banana","Blackberries","Blueberries",
    "Cherries","Kiwi fruit","Mango","Nectarine","Papaya",
    "Peach","Pear","Pineapple","Plum","Raspberries",
    "Strawberries","Watermelon"]
Master_list = vcat(LG_list,H_list,NL_list,F_list) # 81
#   Find portion data for food list --------------------------------------------
function FindPortionData(food_list, verbose)
    #   empty dataframe - don't make df with 0s b/c multiple data vals for food items
    Food_PortionWts = DataFrame(food=[],data_type=[],fdc_id=[],description=[],gram_weight=[])
    for i = 1:length(food_list)
        if verbose == true
            println("============================================")
            println("Finding portion values for "*food_list[i]*"---------")
        end
        #   make string comparison case insensitive
        food_list_item = Unicode.normalize(food_list[i]*",", casefold=true)
        for j = 1:length(USDA_Food_Portion.description)
            USDA_Food_Portion_item = Unicode.normalize(USDA_Food_Portion.description[j], casefold=true)
            if occursin(food_list_item,USDA_Food_Portion_item) == true &&
                (endswith(USDA_Food_Portion.description[j],"raw") == true ||
                endswith(USDA_Food_Portion.description[j],"fresh") == true)
                # also ends with "fresh"
                if verbose == true
                    println("match in "*USDA_Food_Portion.data_type[j])
                end
                if USDA_Food_Portion.data_type[j] == "survey_fndds_food"
                    if verbose == true
                        println("--- description: "*USDA_Food_Portion.description[j])
                        println("--- g/cup = "*string(USDA_Food_Portion.gram_weight[j]))
                    end
                    push!(Food_PortionWts, [food_list[i], USDA_Food_Portion.data_type[j],
                        USDA_Food_Portion.fdc_id[j], USDA_Food_Portion.description[j],
                        USDA_Food_Portion.gram_weight[j]])
                elseif USDA_Food_Portion.data_type[j] == "foundation_food"
                    if verbose == true
                        println("--- description: "*USDA_Food_Portion.description[j])
                        println("--- "*string(USDA_Food_Portion.gram_weight[j])*"g/ "*
                            string(USDA_Food_Portion.amount[j])*" cup")
                    end
                    if USDA_Food_Portion.amount[j] == 1.0
                        push!(Food_PortionWts, [food_list[i], USDA_Food_Portion.data_type[j],
                            USDA_Food_Portion.fdc_id[j], USDA_Food_Portion.description[j],
                            USDA_Food_Portion.gram_weight[j]])
                    elseif USDA_Food_Portion.amount[j] == 0.5
                        push!(Food_PortionWts, [food_list[i], USDA_Food_Portion.data_type[j],
                            USDA_Food_Portion.fdc_id[j], USDA_Food_Portion.description[j],
                            2*USDA_Food_Portion.gram_weight[j]])
                    end
                elseif USDA_Food_Portion.data_type[j] == "sr_legacy_food"
                    if verbose == true
                        println("--- description: "*USDA_Food_Portion.description[j])
                        println("--- "*string(USDA_Food_Portion.gram_weight[j])*"g/ "*
                            string(USDA_Food_Portion.amount[j])*" cup")
                    end
                    if USDA_Food_Portion.amount[j] == 1.0
                        push!(Food_PortionWts, [food_list[i], USDA_Food_Portion.data_type[j],
                            USDA_Food_Portion.fdc_id[j], USDA_Food_Portion.description[j],
                            USDA_Food_Portion.gram_weight[j]])
                    elseif USDA_Food_Portion.amount[j] == 0.5
                        push!(Food_PortionWts, [food_list[i], USDA_Food_Portion.data_type[j],
                            USDA_Food_Portion.fdc_id[j], USDA_Food_Portion.description[j],
                            2*USDA_Food_Portion.gram_weight[j]])
                    end
                end
            end
        end
    end
    return Food_PortionWts
end

Rabbit_Food_PortionWts = FindPortionData(Master_list, true) # 84x5

#   remove outliers - e.g. Java plum result for Plum ---------------------------

filter(row -> !(row.description =="Java-plum, (jambolan), raw"), Rabbit_Food_PortionWts)


# Tabulate nutrient data [per 100g portion] for rabbit safe food ===============
#   combine portion weights + nutrient data =-----------------------------------
Rabbit_FP_Nutrient = innerjoin(Rabbit_Food_PortionWts,USDA_NutrientData, on = :fdc_id) # 5759x15
#   isolate nutrients of interest ----------------------------------------------
#       nutrient codes in "nutrient.csv"
#       Water [g] = 1051; Energy [kcal] = 1008; Protein [g] = 1003; Fat [g] = 1004;
#       Carb [g] = 1005; Fiber [g] = 1079; Sugars [g] = 2000; starch [g] = 1009;
#       Calcium [mg] = 1087
Rabbit_FP_Nutrient_ed = @where(Rabbit_FP_Nutrient,
    in([1051,1008,1003,1004,1005,1079,2000,1009,1087]).(:nutrient_id)) # 633x15
Rabbit_FP_Nutrient_gr = groupby(Rabbit_FP_Nutrient_ed,:fdc_id)
#   tabulate nutrients of interest by USDA ID ----------------------------------
Nutrient_Data = DataFrame(fdc_id=[],water=[],energy=[],protein=[],fat=[],
    carb=[],fiber=[],sugars=[],starch=[],Ca=[])
for i=1:length(Rabbit_FP_Nutrient_gr)
    println("============================================")
    println("Finding nutrient values for "*Rabbit_FP_Nutrient_gr[i].food[1]*"---------")
    #   find indices of nutrients
    water_i = first(indexin(1051,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    energy_i = first(indexin(1008,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    protein_i = first(indexin(1003,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    fat_i = first(indexin(1004,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    carb_i = first(indexin(1005,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    fiber_i = first(indexin(1079,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    sugar_i = first(indexin(2000,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    starch_i = first(indexin(1009,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    calcium_i = first(indexin(1087,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    #=
    water_i = first(findall(x -> x == 1051,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    energy_i = first(findall(x -> x == 1008,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    protein_i = first(findall(x -> x == 1003,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    fat_i = first(findall(x -> x == 1004,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    carb_i = first(findall(x -> x == 1005,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    fiber_i = first(findall(x -> x == 1079,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    sugar_i = first(findall(x -> x == 2000,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    calcium_i = first(findall(x -> x == 1087,Rabbit_FP_Nutrient_gr[i].nutrient_id))
    =#
    #   nutrient values
    water = Rabbit_FP_Nutrient_gr[i].amount[water_i]
    energy = Rabbit_FP_Nutrient_gr[i].amount[energy_i]
    protein = Rabbit_FP_Nutrient_gr[i].amount[protein_i]
    fat = Rabbit_FP_Nutrient_gr[i].amount[fat_i]
    carb = Rabbit_FP_Nutrient_gr[i].amount[carb_i]
    if fiber_i == nothing
        fiber = NaN
    elseif fiber_i > 0
        fiber = Rabbit_FP_Nutrient_gr[i].amount[fiber_i]
    end
    if sugar_i == nothing
        sugar = NaN
    elseif sugar_i > 0
        sugar = Rabbit_FP_Nutrient_gr[i].amount[sugar_i]
    end
    if starch_i == nothing
        starch = NaN
    elseif starch_i > 0
        starch = Rabbit_FP_Nutrient_gr[i].amount[starch_i]
    end
    calcium = Rabbit_FP_Nutrient_gr[i].amount[calcium_i]
    push!(Nutrient_Data, [Rabbit_FP_Nutrient_gr[i].fdc_id[1],
        water,energy,protein,fat,carb,fiber,sugar,starch,calcium])
end

# Combine portion & nutrient data ==============================================
Rabbit_Food_Data = innerjoin(Rabbit_Food_PortionWts, Nutrient_Data, on = :fdc_id)
#CSV.write(dirdata*"Rabbit Food Data.csv", Rabbit_Food_Data)
# remove ------------------------------

#   average values for duplicates ----------------------------------------------


# Convert nutrient data: per 100g to per 1 c. ==================================
water_bycup = Rabbit_Food_Data.water/100 .* Rabbit_Food_Data.gram_weight
energy_bycup = Rabbit_Food_Data.energy/100 .* Rabbit_Food_Data.gram_weight
protein_bycup = Rabbit_Food_Data.protein/100 .* Rabbit_Food_Data.gram_weight
fat_bycup = Rabbit_Food_Data.fat/100 .* Rabbit_Food_Data.gram_weight
carb_bycup = Rabbit_Food_Data.carb/100 .* Rabbit_Food_Data.gram_weight
fiber_bycup = Rabbit_Food_Data.fiber/100 .* Rabbit_Food_Data.gram_weight
sugars_bycup = Rabbit_Food_Data.sugars/100 .* Rabbit_Food_Data.gram_weight
starch_bycup = Rabbit_Food_Data.starch/100 .* Rabbit_Food_Data.gram_weight
ca_bycup = Rabbit_Food_Data.Ca/100 .* Rabbit_Food_Data.gram_weight

Rabbit_Food_Data_bycup = hcat(Rabbit_Food_Data.food, Rabbit_Food_Data.data_type,
    Rabbit_Food_Data.fdc_id,Rabbit_Food_Data.description,
    water_bycup,energy_bycup,protein_bycup,fat_bycup,carb_bycup,fiber_bycup,sugars_bycup,
    starch_bycup,ca_bycup)
Rabbit_Food_Data_bycup = DataFrame(Rabbit_Food_Data_bycup,
    [:"food",:"data_type",:"fdc_id",:"description",:"water",:"energy",:"protein",
    :"fat",:"carb",:"fiber",:"sugars",:"starch",:"Ca"])
#CSV.write(dirdata*"Rabbit Food Data by Cup.csv", Rabbit_Food_Data_bycup)



# end timer ====================================================================
#end
