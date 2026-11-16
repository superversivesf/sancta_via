# Staging review: prayers from the Catholic Prayers app

**125 prayer files** generated from prayers.json (Catholic Prayers app).
None has a text-equivalent in your existing 96. Copy the keepers into assets/prayers/ and delete the rest.

## With standard Latin included (12)

- `divine_mercy_eternal_father`
- `divine_mercy_sorrowful_passion`
- `fatima_decade_prayer`
- `mass_concluding_rites`
- `mass_gospel_dialogue`
- `mass_greeting`
- `mass_invitation_to_communion`
- `mass_invitation_to_prayer`
- `mass_preface_dialogue`
- `mass_sign_of_peace`
- `psalm_91`
- `trisagion`

## Latin exists officially, but not included (long texts - verify from a liturgical source)

- litany_holy_name_of_jesus (Litaniae de Nomine Jesu)
- litany_holy_ghost (Litaniae Spiritui Sancto)
- litany_most_precious_blood (Litaniae Pretiosissimi Sanguinis)
- litany_of_the_saints (Litaniae Sanctorum)

## Flag for review

- act_of_faith / act_of_hope / act_of_love - SV has combined 'Act of Faith, Hope, and Charity'
- act_of_spiritual_communion - SV 'Prayer Before Communion' contains similar act
- prayer_to_the_sacred_heart - SV has 'Prayer to the Sacred Heart of Jesus'; the two novenas are different texts
- hail_joseph - SV has 'Litany of St. Joseph'; this is a different devotion but thematic overlap
- prayer_to_st_anthony_perseverance - source text has dropped words ('importance of persevering in our [faith?] and our practice')
- omnipotentia_patris - app 1 also had 'Prayer to the Most Holy Trinity', an older translation of the same prayer; only this one kept
- mass_invitation_to_communion - SV 'Prayer Before Communion' overlap

## Notes

- Best protection - instructions, not a prayer; excluded
- Miraculous Medal Prayer / 2 - SV has 'O Mary, Conceived Without Sin' (same prayer)
- Prayer 0-15 renamed to proper Station titles

## All files

| File | Prayer | Latin |
|---|---|---|
| `act_of_adoration.json` | Act of Adoration |  |
| `act_of_consecration_holy_spirit.json` | holy_spirit |  |
| `act_of_consecration_sacred_heart.json` | sacred_heart |  |
| `act_of_faith.json` | Act of Faith |  |
| `act_of_hope.json` | Act of Hope |  |
| `act_of_love.json` | Act of Love |  |
| `act_of_spiritual_communion.json` | eucharist |  |
| `adoration_prayer.json` | Adoration Prayer |  |
| `an_act_of_oblation.json` | An Act of Oblation |  |
| `an_act_of_praise.json` | An Act of Praise |  |
| `binding_evil_spirits.json` | Binding Evil Spirits |  |
| `breaking_curses.json` | Breaking Curses |  |
| `breaking_generational_bondage.json` | Breaking Generational Bondage |  |
| `childrens_prayer_for_parents.json` | Children's Prayer for their Parents |  |
| `childrens_prayer_to_mary.json` | Children's Prayer to Mary |  |
| `closing_of_deliverance_prayers.json` | Closing of Deliverance Prayers |  |
| `consecration_to_three_persons.json` | Consecration to the Three Persons |  |
| `denouncing_the_occult.json` | Denouncing the Occult |  |
| `destroying_demonic_influence.json` | Destroying Demonic Influence |  |
| `divine_mercy_closing_prayer.json` | Divine Mercy: Closing Prayer |  |
| `divine_mercy_eternal_father.json` | Divine Mercy: Eternal Father | yes |
| `divine_mercy_opening.json` | Divine Mercy: Opening Prayer |  |
| `divine_mercy_sorrowful_passion.json` | Divine Mercy: For the Sake of His Sorrowful Passion | yes |
| `eucharistic_thanksgiving_holy_trinity.json` | eucharist |  |
| `evening_prayer.json` | Evening Prayer |  |
| `fatima_decade_prayer.json` | Fatima Prayer (O My Jesus) | yes |
| `general_thanksgiving_prayer.json` | Prayer of Thanksgiving |  |
| `give_me_strength_lord.json` | Give Me Strength, Lord |  |
| `hail_joseph.json` | Hail, Joseph (St. Joseph Devotion) |  |
| `healing_the_family_tree.json` | Healing the Family Tree |  |
| `holy_face_prayer.json` | The Holy Face |  |
| `holy_spirit_prayer.json` | Holy Spirit Prayer |  |
| `in_praise_of_holy_trinity.json` | In Praise of the Holy Trinity |  |
| `litany_holy_ghost.json` | Litany of the Holy Ghost |  |
| `litany_holy_name_of_jesus.json` | Litany of the Holy Name of Jesus |  |
| `litany_most_precious_blood.json` | The Litany of the Most Precious Blood of Jesus |  |
| `litany_of_humility.json` | Litany of Humility |  |
| `litany_of_the_saints.json` | Litany of the Saints |  |
| `mary_mother_of_grace.json` | Mary, Mother of Grace |  |
| `mass_concluding_rites.json` | Mass Concluding Rites | yes |
| `mass_gospel_dialogue.json` | Mass Gospel Dialogue | yes |
| `mass_greeting.json` | Mass Greeting | yes |
| `mass_invitation_to_communion.json` | Mass Invitation to Communion | yes |
| `mass_invitation_to_prayer.json` | Mass Invitation to Prayer | yes |
| `mass_preface_dialogue.json` | Mass Preface Dialogue (Sursum Corda) | yes |
| `mass_sign_of_peace.json` | Mass Sign of Peace | yes |
| `night_prayer.json` | Night Prayer |  |
| `novena_annunciation.json` | Annunciation Novena |  |
| `novena_ascension.json` | Ascension Novena |  |
| `novena_assumption.json` | Novena to the Assumption of the Virgin Mary |  |
| `novena_divine_child_jesus.json` | Novena to the Divine Child Jesus |  |
| `novena_holy_face.json` | Novena to the Holy Face |  |
| `novena_holy_name.json` | Novena to the Holy Name |  |
| `novena_holy_spirit.json` | Novena to the Holy Spirit |  |
| `novena_immaculate_conception.json` | Immaculate Conception Novena |  |
| `novena_immaculate_heart_of_mary.json` | Novena Prayer to the Immaculate Heart of Mary |  |
| `novena_our_lady_of_good_remedy.json` | Our Lady of Good Remedy Novena |  |
| `novena_our_lady_of_holy_rosary.json` | Our Lady Of The Holy Rosary Novena |  |
| `novena_our_lady_of_hope.json` | Novena to our Lady of Hope |  |
| `novena_our_lady_of_lourdes.json` | Novena to Our Lady of Lourdes |  |
| `novena_precious_blood.json` | Novena to the Precious Blood |  |
| `novena_sacred_heart_of_jesus.json` | Novena to the Sacred Heart of Jesus |  |
| `novena_to_christ_the_king.json` | Novena to Christ the King |  |
| `novena_to_the_sacred_heart.json` | Novena to the Sacred Heart |  |
| `o_eternal_trinity.json` | trinity |  |
| `omnipotentia_patris.json` | Omnipotence of the Father |  |
| `parents_prayer_for_children.json` | Parent's Prayer for their Children |  |
| `petition_to_holy_trinity.json` | Petition to the Holy Trinity |  |
| `prayer_after_rosary.json` | Prayer After the Rosary |  |
| `prayer_against_evil.json` | Prayer against Evil |  |
| `prayer_against_malefice.json` | Prayer Against Malefice |  |
| `prayer_for_a_family.json` | Prayer for a Family |  |
| `prayer_for_a_good_husband_or_wife.json` | A Prayer for a Good Husband or Wife |  |
| `prayer_for_a_spiritual_canopy.json` | Prayer for a Spiritual Canopy |  |
| `prayer_for_deliverance.json` | Prayer for Deliverance |  |
| `prayer_for_healing.json` | Prayer for Healing |  |
| `prayer_for_healing_look_upon_me.json` | Prayer for Healing (Look Upon Me with Eyes of Mercy) |  |
| `prayer_for_inner_healing.json` | Prayer for Inner Healing |  |
| `prayer_for_the_healer.json` | Prayer for the Healer |  |
| `prayer_in_praise_of_gods_greatness.json` | A Prayer in Praise of God's Greatness |  |
| `prayer_of_a_child.json` | Prayer of a Child |  |
| `prayer_of_a_husband_or_wife.json` | Prayer of a Husband or Wife |  |
| `prayer_of_st_anselm.json` | Prayer of St. Anselm |  |
| `prayer_of_st_augustine.json` | Prayer of St. Augustine |  |
| `prayer_of_st_benedict.json` | Prayer of St. Benedict |  |
| `prayer_of_st_columba.json` | Prayer of St. Columba |  |
| `prayer_of_st_dominic.json` | Prayer of St. Dominic |  |
| `prayer_of_st_ethelwold.json` | Prayer of St. Ethelwold |  |
| `prayer_of_st_francis_canticle.json` | Prayer of St. Francis (Praise of God Most High, Canticle of the Sun) |  |
| `prayer_of_st_gregory.json` | Prayer of St. Gregory |  |
| `prayer_of_st_ignatius_generous_lord.json` | Prayer of St. Ignatius (Dearest Lord, Teach Me to Be Generous) |  |
| `prayer_of_st_patrick_arising.json` | Prayer of St. Patrick (I Arise Today) |  |
| `prayer_of_st_teresa_of_avila_serving.json` | Prayer of St. Teresa of Avila (Govern Everything by Your Wisdom) |  |
| `prayer_of_st_thomas_aquinas_after_mass.json` | Prayer of St. Thomas Aquinas (After Mass) |  |
| `prayer_of_st_thomas_aquinas_before_mass.json` | Prayer of St. Thomas Aquinas (Before Mass) |  |
| `prayer_of_surrender_divine_will.json` | A Prayer of Surrender to the Divine Will |  |
| `prayer_to_god_the_father.json` | Prayer to God the Father |  |
| `prayer_to_god_the_holy_spirit.json` | Prayer to God the Holy Spirit |  |
| `prayer_to_god_the_son.json` | Prayer to God the Son |  |
| `prayer_to_holy_trinity_creator.json` | Prayer to the Holy Trinity (Glory Be to the Father Who Created Me) |  |
| `prayer_to_holy_trinity_i_adore.json` | Prayer to the Holy Trinity (I Adore Thee, O My God) |  |
| `prayer_to_indwelling_trinity.json` | O Most Holy Trinity, I Adore You |  |
| `prayer_to_st_anthony_perseverance.json` | Prayer to St. Anthony (Perseverance) |  |
| `prayer_to_st_christopher.json` | Prayer to St. Christopher |  |
| `prayer_to_st_joseph_2.json` | Prayer to St. Joseph II |  |
| `prayer_to_st_joseph_3.json` | Prayer to St. Joseph III |  |
| `psalm_91.json` | Psalm 91 (He Who Dwells in the Shelter of the Most High) | yes |
| `station_0.json` | Stations of the Cross: Opening Prayer |  |
| `station_10_stripped.json` | Tenth Station: Jesus is Stripped of His Garments |  |
| `station_11_nailed.json` | Eleventh Station: Jesus is Nailed to the Cross |  |
| `station_12_dies.json` | Twelfth Station: Jesus Dies on the Cross |  |
| `station_13_taken_down.json` | Thirteenth Station: Jesus is Taken Down from the Cross |  |
| `station_14_tomb.json` | Fourteenth Station: Jesus is Laid in the Tomb |  |
| `station_15.json` | Stations of the Cross: Closing Prayer |  |
| `station_1_condemned.json` | First Station: Jesus is Condemned to Death |  |
| `station_2_cross.json` | Second Station: Jesus Takes Up His Cross |  |
| `station_3_first_fall.json` | Third Station: Jesus Falls the First Time |  |
| `station_4_meets_mother.json` | Fourth Station: Jesus Meets His Mother |  |
| `station_5_simon.json` | Fifth Station: Simon of Cyrene Helps Jesus |  |
| `station_6_veronica.json` | Sixth Station: Veronica Wipes the Face of Jesus |  |
| `station_7_second_fall.json` | Seventh Station: Jesus Falls the Second Time |  |
| `station_8_women.json` | Eighth Station: Jesus Speaks to the Women of Jerusalem |  |
| `station_9_third_fall.json` | Ninth Station: Jesus Falls the Third Time |  |
| `to_the_trinity_dwelling_in_the_soul.json` | To the Trinity Dwelling in the Soul |  |
| `trisagion.json` | Trisagion | yes |
