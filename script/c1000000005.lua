local s,id=GetID()
function s.initial_effect(c)
    Link.AddProcedure(c, aux.FilterBoolFunctionEx(Card.IsCode, 1000000001), 1, 1)
    c:EnableReviveLimit()

    local e1=Effect.CreateEffect(c)
    e1:SetDescription(aux.Stringid(id,0))
    e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
    e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F) -- Forced trigger
    e1:SetCode(EVENT_LEAVE_FIELD)
    e1:SetProperty(EFFECT_FLAG_DELAY+EFFECT_FLAG_DAMAGE_STEP)
    e1:SetCondition(s.spcon)
    e1:SetTarget(s.sptg)
    e1:SetOperation(s.spop)
    c:RegisterEffect(e1)

    local e2=Effect.CreateEffect(c)
    e2:SetDescription(aux.Stringid(id,1))
    e2:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOEXTRA)
    e2:SetType(EFFECT_TYPE_IGNITION)
    e2:SetRange(LOCATION_MZONE)
    e2:SetCondition(s.swarmcon)
    e2:SetTarget(s.swarmtg)
    e2:SetOperation(s.swarmop)
    c:RegisterEffect(e2)

    -- 3: Tribute 1 Tuner to cheat out a Synchro of the same level
    local e3=Effect.CreateEffect(c)
    e3:SetDescription(aux.Stringid(id,2))
    e3:SetCategory(CATEGORY_SPECIAL_SUMMON)
    e3:SetType(EFFECT_TYPE_IGNITION)
    e3:SetRange(LOCATION_MZONE)
    e3:SetCost(s.synchcost)
    e3:SetTarget(s.synchtg)
    e3:SetOperation(s.synchop)
    c:RegisterEffect(e3)
end

-- E1: Float logic
function s.spcon(e,tp,eg,ep,ev,re,r,rp)
    return e:GetHandler():IsPreviousPosition(POS_FACEUP) and e:GetHandler():IsPreviousLocation(LOCATION_ONFIELD)
end
function s.spfilter(c,e,tp)
    return c:IsSetCard(0xf00) and c:IsType(TYPE_TUNER) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.sptg(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then return true end -- Mandatory trigger check
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_DECK)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp)
    if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
    local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_DECK,0,1,1,nil,e,tp)
    if #g>0 then
        Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP)
    end
end

-- E2: GY Swarm logic
function s.swarmcon(e,tp,eg,ep,ev,re,r,rp)
    -- "If you control no other cards" (Only this card)
    return Duel.GetFieldGroupCount(tp,LOCATION_ONFIELD,0)==1
end
function s.swarmtg(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then return Duel.IsExistingMatchingCard(Card.IsCode,tp,LOCATION_GRAVE,0,1,nil,1000000001) end
    Duel.SetOperationInfo(0,CATEGORY_TOEXTRA,e:GetHandler(),1,0,0)
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_GRAVE)
end
function s.swarmop(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    if c:IsRelateToEffect(e) and Duel.SendtoDeck(c,nil,SEQ_DECKTOP,REASON_EFFECT)>0 and c:IsLocation(LOCATION_EXTRA) then
        local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
        if ft<=0 then return end
        local g=Duel.GetMatchingGroup(Card.IsCode,tp,LOCATION_GRAVE,0,nil,1000000001)
        if #g>0 then
            if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then ft=1 end
            Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
            local sg=g:Select(tp,1,ft,nil)
            Duel.SpecialSummon(sg,0,tp,tp,false,false,POS_FACEUP)
        end
    end
end

-- E3: Synchro Cheat logic
function s.synchfilter(c,e,tp,lv)
    return c:IsSetCard(0xf00) and c:IsType(TYPE_SYNCHRO) and c:GetLevel()==lv and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
-- Updated Filter: Now expects lv as the first argument after 'c'
function s.costfilter(c,lv,e,tp)
    return c:IsSetCard(0xf00) and c:IsType(TYPE_TUNER) and c:GetLevel()>0 
        and Duel.IsExistingMatchingCard(s.synchfilter,tp,LOCATION_EXTRA,0,1,nil,e,tp,c:GetLevel())
end

function s.synchcost(e,tp,eg,ep,ev,re,r,rp,chk)
    -- The 'nil, e, tp' at the end are the extra arguments passed to s.costfilter
    if chk==0 then return Duel.CheckReleaseGroupCost(tp,s.costfilter,1,false,nil,nil,e,tp) end
    local g=Duel.SelectReleaseGroupCost(tp,s.costfilter,1,1,false,nil,nil,e,tp)
    
    local tc=g:GetFirst()
    e:SetLabel(tc:GetLevel()) -- Lock in the level of the monster we actually chose
    Duel.Release(g,REASON_COST)
end
function s.synchtg(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then return true end
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_EXTRA)
end
function s.synchop(e,tp,eg,ep,ev,re,r,rp)
    local lv=e:GetLabel()
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
    local g=Duel.SelectMatchingCard(tp,s.synchfilter,tp,LOCATION_EXTRA,0,1,1,nil,e,tp,lv)
    if #g>0 then
        Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP)
    end
end