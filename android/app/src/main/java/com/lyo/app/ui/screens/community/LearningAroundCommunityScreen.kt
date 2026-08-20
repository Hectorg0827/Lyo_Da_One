package com.lyo.app.ui.screens.community

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityPostDto
import com.lyo.app.data.api.LearningNodeDto
import com.lyo.app.data.api.LearningNodeSaveRequest
import com.lyo.app.data.api.MyCommunityResponseDto
import com.lyo.app.data.sync.SyncClient
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.nio.charset.StandardCharsets
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private data class CommunityCategory(
    val id: String,
    val label: String,
    val icon: ImageVector,
    val color: String,
)

private val learningCategories = listOf(
    CommunityCategory("event", "Events", Icons.Default.CalendarMonth, "#F97316"),
    CommunityCategory("workshop", "Workshops", Icons.Default.School, "#F59E0B"),
    CommunityCategory("class", "Classes", Icons.Default.School, "#8B5CF6"),
    CommunityCategory("study_group", "Study groups", Icons.Default.Groups, "#3B82F6"),
    CommunityCategory("tutor", "Tutors", Icons.Default.School, "#EC4899"),
    CommunityCategory("library", "Libraries", Icons.Default.Place, "#10B981"),
    CommunityCategory("museum", "Museums", Icons.Default.Place, "#06B6D4"),
    CommunityCategory("educational_center", "Learning centers", Icons.Default.School, "#6366F1"),
)

private fun categoryFor(id: String): CommunityCategory =
    learningCategories.firstOrNull { it.id == id } ?: learningCategories.first()

@Composable
fun LearningAroundCommunityScreen(nav: NavHostController) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selectedTab by remember { mutableIntStateOf(0) }
    var viewMode by remember { mutableStateOf("map") }
    var query by remember { mutableStateOf("") }
    var selectedCategories by remember { mutableStateOf(setOf<String>()) }
    var latitude by remember { mutableStateOf(40.7128) }
    var longitude by remember { mutableStateOf(-74.0060) }
    var locationLabel by remember { mutableStateOf("New York City") }
    var nodes by remember { mutableStateOf<List<LearningNodeDto>>(emptyList()) }
    var myCommunity by remember { mutableStateOf<MyCommunityResponseDto?>(null) }
    var posts by remember { mutableStateOf<List<CommunityPostDto>>(emptyList()) }
    var selectedNode by remember { mutableStateOf<LearningNodeDto?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var busyKey by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableIntStateOf(0) }
    var createMenuExpanded by remember { mutableStateOf(false) }

    @SuppressLint("MissingPermission")
    fun useDeviceLocation() {
        locationLabel = "Locating…"
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val location = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { provider -> runCatching { manager.isProviderEnabled(provider) }.getOrDefault(false) }
            .mapNotNull { provider -> runCatching { manager.getLastKnownLocation(provider) }.getOrNull() }
            .maxByOrNull { it.time }
        if (location != null) {
            latitude = location.latitude
            longitude = location.longitude
            locationLabel = "Current location"
        } else {
            locationLabel = "Location unavailable"
        }
    }

    val locationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { result ->
        if (result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            result[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        ) {
            useDeviceLocation()
        } else {
            locationLabel = "New York City"
        }
    }

    fun requestLocation() {
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) useDeviceLocation()
        else locationPermission.launch(
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ),
        )
    }

    LaunchedEffect(Unit) { requestLocation() }

    LaunchedEffect(latitude, longitude, selectedCategories, query, reload) {
        delay(250)
        loading = true
        error = null
        runCatching {
            ApiClient.api.nearbyLearning(
                latitude = latitude,
                longitude = longitude,
                radiusKm = 20.0,
                categories = selectedCategories.takeIf { it.isNotEmpty() }?.sorted()?.joinToString(","),
                query = query.trim().ifEmpty { null },
            )
        }.onSuccess { response ->
            nodes = response.items
            selectedNode = selectedNode?.let { current ->
                response.items.firstOrNull { it.key == current.key } ?: current
            }
        }.onFailure { throwable ->
            error = communityMapError(throwable)
        }
        loading = false
    }

    LaunchedEffect(reload) {
        runCatching { ApiClient.api.myCommunity() }
            .onSuccess { state ->
                myCommunity = state
                selectedNode?.let { current ->
                    if (nodes.none { it.key == current.key }) {
                        selectedNode = state.savedNodes.firstOrNull { it.key == current.key }
                    }
                }
            }
    }

    LaunchedEffect(selectedTab, reload) {
        if (selectedTab == 2) {
            runCatching { ApiClient.api.communityPosts(1, 30).items.orEmpty() }
                .onSuccess { posts = it }
        }
    }

    LaunchedEffect(Unit) {
        SyncClient.events.collect { event ->
            if (event.eventType in setOf("community_updated", "context_updated")) reload += 1
        }
    }

    fun refreshAfter(action: suspend () -> Unit, nodeKey: String) {
        if (busyKey != null) return
        busyKey = nodeKey
        error = null
        scope.launch {
            runCatching { action() }
                .onSuccess { reload += 1 }
                .onFailure { error = communityMapError(it) }
            busyKey = null
        }
    }

    fun toggleSave(node: LearningNodeDto) = refreshAfter(
        action = {
            if (node.isSaved) ApiClient.api.unsaveLearningNode(node.kind, node.id)
            else ApiClient.api.saveLearningNode(node.kind, node.id, LearningNodeSaveRequest(node))
            if (selectedNode?.key == node.key) {
                selectedNode = node.copy(isSaved = !node.isSaved)
            }
        },
        nodeKey = node.key,
    )

    fun primaryAction(node: LearningNodeDto) = refreshAfter(
        action = {
            when (node.kind) {
                "event" -> {
                    if (node.isAttending) ApiClient.api.unattendEvent(node.id)
                    else ApiClient.api.attendEvent(node.id)
                    if (selectedNode?.key == node.key) {
                        selectedNode = node.copy(isAttending = !node.isAttending)
                    }
                }
                "study_group" -> {
                    if (node.isJoined) ApiClient.api.leaveGroup(node.id)
                    else ApiClient.api.joinGroup(node.id)
                    if (selectedNode?.key == node.key) {
                        selectedNode = node.copy(isJoined = !node.isJoined)
                    }
                }
            }
        },
        nodeKey = node.key,
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Community", style = MaterialTheme.typography.headlineSmall, color = TextPrimary, fontWeight = FontWeight.Bold)
                Text("Learn from the world and people around you", style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            }
            Box {
                IconButton(onClick = { createMenuExpanded = true }) {
                    Icon(Icons.Default.Add, contentDescription = "Create learning node", tint = TextPrimary)
                }
                DropdownMenu(expanded = createMenuExpanded, onDismissRequest = { createMenuExpanded = false }) {
                    DropdownMenuItem(text = { Text("Create event or class") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_EVENT) })
                    DropdownMenuItem(text = { Text("Create study group") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_GROUP) })
                    DropdownMenuItem(text = { Text("Offer tutoring") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_TUTOR) })
                    DropdownMenuItem(text = { Text("Create activity post") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_POST) })
                }
            }
        }

        CommunityTabs(selectedTab = selectedTab, onSelect = { selectedTab = it })

        when (selectedTab) {
            0 -> AroundMeTab(
                query = query,
                onQueryChange = { query = it },
                selectedCategories = selectedCategories,
                onToggleCategory = { category ->
                    selectedCategories = if (category in selectedCategories) selectedCategories - category else selectedCategories + category
                },
                onClearCategories = { selectedCategories = emptySet() },
                locationLabel = locationLabel,
                onLocate = ::requestLocation,
                viewMode = viewMode,
                onViewModeChange = { viewMode = it },
                nodes = nodes,
                latitude = latitude,
                longitude = longitude,
                selectedNode = selectedNode,
                onSelectNode = { selectedNode = it },
                onCloseNode = { selectedNode = null },
                loading = loading,
                error = error,
                busyKey = busyKey,
                onSave = ::toggleSave,
                onPrimary = ::primaryAction,
                onOpenCourse = { node -> node.courseId?.let { nav.navigate(Routes.courseDetail(it.toString())) } },
                onAskLyo = { nav.navigate(Routes.CHAT) },
                onOpenSource = { url ->
                    val uri = Uri.parse(url)
                    if (uri.scheme == "https" || uri.scheme == "http") {
                        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    }
                },
            )
            1 -> MyCommunityTab(
                state = myCommunity,
                nav = nav,
                onOpenNode = { node ->
                    selectedNode = nodes.firstOrNull { it.key == node.key } ?: node
                    selectedTab = 0
                },
            )
            else -> CommunityActivityTab(posts = posts, nav = nav)
        }
    }
}

@Composable
private fun CommunityTabs(selectedTab: Int, onSelect: (Int) -> Unit) {
    val labels = listOf("Around Me", "My Community", "Activity")
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp),
    ) {
        labels.forEachIndexed { index, label ->
            Surface(
                color = if (index == selectedTab) LyoPurple else SurfaceElevated,
                shape = RoundedCornerShape(10.dp),
                modifier = Modifier
                    .weight(1f)
                    .clickable { onSelect(index) },
            ) {
                Text(
                    label,
                    color = if (index == selectedTab) Color.White else TextSecondary,
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.padding(vertical = 10.dp),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun AroundMeTab(
    query: String,
    onQueryChange: (String) -> Unit,
    selectedCategories: Set<String>,
    onToggleCategory: (String) -> Unit,
    onClearCategories: () -> Unit,
    locationLabel: String,
    onLocate: () -> Unit,
    viewMode: String,
    onViewModeChange: (String) -> Unit,
    nodes: List<LearningNodeDto>,
    latitude: Double,
    longitude: Double,
    selectedNode: LearningNodeDto?,
    onSelectNode: (LearningNodeDto) -> Unit,
    onCloseNode: () -> Unit,
    loading: Boolean,
    error: String?,
    busyKey: String?,
    onSave: (LearningNodeDto) -> Unit,
    onPrimary: (LearningNodeDto) -> Unit,
    onOpenCourse: (LearningNodeDto) -> Unit,
    onAskLyo: () -> Unit,
    onOpenSource: (String) -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            singleLine = true,
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            placeholder = { Text("Libraries, classes, tutors, events…") },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 12.dp),
        ) {
            OutlinedButton(onClick = onLocate, contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)) {
                Icon(Icons.Default.MyLocation, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(locationLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { onViewModeChange("map") }) {
                Icon(Icons.Default.Map, contentDescription = null, tint = if (viewMode == "map") LyoPurple else TextSecondary)
                Text("Map", color = if (viewMode == "map") LyoPurple else TextSecondary)
            }
            TextButton(onClick = { onViewModeChange("list") }) {
                Icon(Icons.Default.List, contentDescription = null, tint = if (viewMode == "list") LyoPurple else TextSecondary)
                Text("List", color = if (viewMode == "list") LyoPurple else TextSecondary)
            }
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 5.dp),
        ) {
            item {
                FilterChip(selected = selectedCategories.isEmpty(), onClick = onClearCategories, label = { Text("All learning") })
            }
            items(learningCategories) { category ->
                FilterChip(
                    selected = category.id in selectedCategories,
                    onClick = { onToggleCategory(category.id) },
                    leadingIcon = { Icon(category.icon, contentDescription = null, modifier = Modifier.size(16.dp)) },
                    label = { Text(category.label) },
                )
            }
        }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) }

        if (loading && nodes.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = LyoPurple) }
        } else if (viewMode == "map") {
            Box(modifier = Modifier.fillMaxSize()) {
                LearningMapWebView(
                    nodes = nodes,
                    latitude = latitude,
                    longitude = longitude,
                    selectedKey = selectedNode?.key,
                    onSelect = onSelectNode,
                    modifier = Modifier.fillMaxSize(),
                )
                Surface(
                    color = SurfaceElevated.copy(alpha = 0.94f),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(12.dp),
                ) {
                    Text("${nodes.size} learning opportunities nearby", color = TextPrimary, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp))
                }
                selectedNode?.let { node ->
                    LearningNodeSheet(
                        node = node,
                        busy = busyKey == node.key,
                        onClose = onCloseNode,
                        onSave = { onSave(node) },
                        onPrimary = { onPrimary(node) },
                        onOpenCourse = { onOpenCourse(node) },
                        onAskLyo = onAskLyo,
                        onOpenSource = onOpenSource,
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(12.dp),
                    )
                }
            }
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(12.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(nodes, key = { it.key }) { node ->
                    LearningNodeCard(node = node, onClick = { onSelectNode(node); onViewModeChange("map") })
                }
                if (nodes.isEmpty()) item { Text("No matching learning nodes in this area yet.", color = TextSecondary, modifier = Modifier.padding(24.dp)) }
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun LearningMapWebView(
    nodes: List<LearningNodeDto>,
    latitude: Double,
    longitude: Double,
    selectedKey: String?,
    onSelect: (LearningNodeDto) -> Unit,
    modifier: Modifier = Modifier,
) {
    val nodeByKey = remember(nodes) { nodes.associateBy { it.key } }
    val bridge = remember { LearningMapBridge() }
    bridge.onSelected = { key -> nodeByKey[key]?.let(onSelect) }
    val html = remember(nodes, latitude, longitude, selectedKey) {
        learningMapHtml(nodes, latitude, longitude, selectedKey)
    }
    var webView: WebView? by remember { mutableStateOf(null) }
    AndroidView(
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                webViewClient = WebViewClient()
                addJavascriptInterface(bridge, "LyoCommunity")
                tag = html
                loadDataWithBaseURL("https://lyoai.app", html, "text/html", "UTF-8", null)
                webView = this
            }
        },
        update = { view ->
            if (view.tag != html) {
                view.tag = html
                view.loadDataWithBaseURL("https://lyoai.app", html, "text/html", "UTF-8", null)
            }
        },
        modifier = modifier,
    )
    DisposableEffect(Unit) {
        onDispose {
            webView?.removeJavascriptInterface("LyoCommunity")
            webView?.destroy()
            webView = null
        }
    }
}

private class LearningMapBridge {
    var onSelected: (String) -> Unit = {}

    @JavascriptInterface
    fun selectNode(key: String) {
        Handler(Looper.getMainLooper()).post { onSelected(key) }
    }
}

private fun learningMapHtml(
    nodes: List<LearningNodeDto>,
    latitude: Double,
    longitude: Double,
    selectedKey: String?,
): String {
    val json = ApiClient.gson.toJson(nodes)
    val payload = Base64.encodeToString(json.toByteArray(StandardCharsets.UTF_8), Base64.NO_WRAP)
    val selected = ApiClient.gson.toJson(selectedKey)
    return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
        <style>html,body,#map{height:100%;margin:0;background:#0B1230}.pin{display:grid;width:34px;height:34px;place-items:center;border:3px solid white;border-radius:50% 50% 50% 8px;color:white;font:800 12px sans-serif;box-shadow:0 6px 18px #0008;transform:scale(var(--s,1))}.leaflet-control-attribution{background:#0E173Ddd!important;color:#aaa!important}.leaflet-control-attribution a{color:#A78BFA!important}</style>
        </head><body><div id="map"></div><script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script><script>
        const bytes=Uint8Array.from(atob('$payload'),c=>c.charCodeAt(0));const nodes=JSON.parse(new TextDecoder().decode(bytes));const selected=$selected;
        const colors={event:'#F97316',workshop:'#F59E0B',class:'#8B5CF6',study_group:'#3B82F6',tutor:'#EC4899',library:'#10B981',museum:'#06B6D4',educational_center:'#6366F1'};
        const glyphs={event:'●',workshop:'W',class:'C',study_group:'G',tutor:'T',library:'L',museum:'M',educational_center:'E'};
        const map=L.map('map',{zoomControl:false}).setView([$latitude,$longitude],13);L.control.zoom({position:'bottomright'}).addTo(map);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'&copy; OpenStreetMap contributors'}).addTo(map);
        L.circleMarker([$latitude,$longitude],{radius:8,color:'#fff',weight:3,fillColor:'#6366F1',fillOpacity:1}).bindTooltip('You are here').addTo(map);
        const bounds=[];nodes.forEach(n=>{if(!Number.isFinite(n.latitude)||!Number.isFinite(n.longitude))return;bounds.push([n.latitude,n.longitude]);const icon=L.divIcon({className:'',html:`<span class="pin" style="background:${'$'}{colors[n.category]};--s:${'$'}{n.key===selected?1.18:1}">${'$'}{glyphs[n.category]}</span>`,iconSize:[38,42],iconAnchor:[19,40]});L.marker([n.latitude,n.longitude],{icon,title:n.title}).on('click',()=>LyoCommunity.selectNode(n.key)).addTo(map)});
        if(bounds.length>1&&!selected)map.fitBounds(bounds,{padding:[42,42],maxZoom:14});const active=nodes.find(n=>n.key===selected);if(active&&active.latitude!=null)map.panTo([active.latitude,active.longitude]);
        </script></body></html>
    """.trimIndent()
}

@Composable
private fun LearningNodeSheet(
    node: LearningNodeDto,
    busy: Boolean,
    onClose: () -> Unit,
    onSave: () -> Unit,
    onPrimary: () -> Unit,
    onOpenCourse: () -> Unit,
    onAskLyo: () -> Unit,
    onOpenSource: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val category = categoryFor(node.category)
    val primaryLabel = when (node.kind) {
        "event" -> if (node.isAttending) "Leave event" else "RSVP"
        "study_group" -> if (node.isJoined) "Leave group" else "Join group"
        else -> null
    }
    Surface(color = SurfaceElevated.copy(alpha = 0.97f), shape = RoundedCornerShape(18.dp), shadowElevation = 14.dp, modifier = modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.Top) {
                Surface(color = LyoPurple.copy(alpha = 0.18f), shape = CircleShape) { Icon(category.icon, contentDescription = null, tint = LyoPurple, modifier = Modifier.padding(10.dp)) }
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(category.label.uppercase(), style = MaterialTheme.typography.labelSmall, color = TextSecondary)
                    Text(node.title, style = MaterialTheme.typography.titleMedium, color = TextPrimary, fontWeight = FontWeight.SemiBold)
                    Text(nodeMeta(node), style = MaterialTheme.typography.bodySmall, color = TextSecondary)
                }
                IconButton(onClick = onClose) { Icon(Icons.Default.Close, contentDescription = "Close details", tint = TextSecondary) }
            }
            node.description?.takeIf { it.isNotBlank() }?.let { Text(it, maxLines = 3, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = TextSecondary) }
            node.locationName?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = TextSecondary) }
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                primaryLabel?.let { label -> item { Button(onClick = onPrimary, enabled = !busy, colors = ButtonDefaults.buttonColors(containerColor = LyoPurple)) { Text(if (busy) "Updating…" else label) } } }
                item { OutlinedButton(onClick = onSave, enabled = !busy) { Icon(if (node.isSaved) Icons.Default.Bookmark else Icons.Outlined.BookmarkBorder, contentDescription = null, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text(if (node.isSaved) "Saved" else "Save") } }
                node.meetingUrl?.let { meetingUrl ->
                    item { OutlinedButton(onClick = { onOpenSource(meetingUrl) }) { Text("Join online") } }
                }
                if (node.courseId != null) item { OutlinedButton(onClick = onOpenCourse) { Icon(Icons.Default.School, contentDescription = null, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text("Course") } }
                item { OutlinedButton(onClick = onAskLyo) { Icon(Icons.Default.SmartToy, contentDescription = null, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text("Ask Lyo") } }
                node.sourceUrl?.let { sourceUrl ->
                    item { OutlinedButton(onClick = { onOpenSource(sourceUrl) }) { Text("Details") } }
                }
            }
        }
    }
}

@Composable
private fun LearningNodeCard(node: LearningNodeDto, onClick: () -> Unit) {
    val category = categoryFor(node.category)
    Surface(color = SurfaceElevated, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(verticalAlignment = Alignment.Top, modifier = Modifier.padding(14.dp)) {
            Icon(category.icon, contentDescription = null, tint = LyoPurple, modifier = Modifier.size(24.dp))
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row {
                    Text(node.title, color = TextPrimary, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    if (node.isSaved) Icon(Icons.Default.Bookmark, contentDescription = "Saved", tint = LyoPurple, modifier = Modifier.size(18.dp))
                }
                Text(nodeMeta(node), color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                node.locationName?.let { Text(it, color = TextSecondary, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis) }
            }
        }
    }
}

@Composable
private fun MyCommunityTab(
    state: MyCommunityResponseDto?,
    nav: NavHostController,
    onOpenNode: (LearningNodeDto) -> Unit,
) {
    if (state == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = LyoPurple) }
        return
    }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(14.dp), modifier = Modifier.fillMaxSize()) {
        item { SectionTitle(Icons.Default.Bookmark, "Saved learning", "Synced to your Lyo account") }
        items(state.savedNodes, key = { it.key }) { node ->
            LearningNodeCard(node = node, onClick = { onOpenNode(node) })
        }
        if (state.savedNodes.isEmpty()) item { EmptyCommunityText("Save a map node and it will appear here on every device.") }
        item { SectionTitle(Icons.Default.Groups, "Joined groups") }
        items(state.joinedGroups, key = { it.idStr }) { group ->
            AccountCard(title = group.name ?: "Study group", subtitle = "${group.memberCount ?: 0} members · ${group.location ?: if (group.isOnline == true) "Online" else ""}")
        }
        if (state.joinedGroups.isEmpty()) item { EmptyCommunityText("You have not joined a study group yet.") }
        item { SectionTitle(Icons.Default.CalendarMonth, "Your events") }
        items(state.attendingEvents, key = { it.idStr }) { event -> AccountCard(event.displayTitle, listOfNotNull(formatNodeDate(event.startTime), event.location).joinToString(" · ")) }
        if (state.attendingEvents.isEmpty()) item { EmptyCommunityText("No upcoming events on this account.") }
        item { SectionTitle(Icons.Default.Groups, "People you follow") }
        items(state.following, key = { it.id }) { person -> AccountCard(person.name, "Open profile", onClick = { nav.navigate(Routes.userProfile(person.id.toString())) }) }
        if (state.following.isEmpty()) item { EmptyCommunityText("People you follow will appear here.") }
    }
}

@Composable
private fun CommunityActivityTab(posts: List<CommunityPostDto>, nav: NavHostController) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(14.dp), modifier = Modifier.fillMaxSize()) {
        items(posts, key = { it.idStr }) { post ->
            Surface(color = SurfaceElevated, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth().clickable { nav.navigate(Routes.postDetail(post.idStr)) }) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(14.dp)) {
                    Text(post.authorName ?: "Member", color = TextPrimary, fontWeight = FontWeight.SemiBold)
                    Text(post.content.orEmpty(), color = TextSecondary, maxLines = 6, overflow = TextOverflow.Ellipsis)
                    Text("${post.likeCount ?: 0} likes · ${post.commentCount ?: 0} comments", color = TextSecondary, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
        if (posts.isEmpty()) item { EmptyCommunityText("No Community activity yet.") }
    }
}

@Composable
private fun SectionTitle(icon: ImageVector, title: String, caption: String? = null) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = LyoPurple, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, color = TextPrimary, fontWeight = FontWeight.SemiBold)
        caption?.let { Spacer(Modifier.width(8.dp)); Text(it, color = TextSecondary, style = MaterialTheme.typography.labelSmall) }
    }
}

@Composable
private fun AccountCard(title: String, subtitle: String, onClick: (() -> Unit)? = null) {
    Surface(color = SurfaceElevated, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(title, color = TextPrimary, fontWeight = FontWeight.SemiBold)
            if (subtitle.isNotBlank()) Text(subtitle, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun EmptyCommunityText(text: String) {
    Text(text, color = TextSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(vertical = 8.dp))
}

private fun nodeMeta(node: LearningNodeDto): String = listOfNotNull(
    categoryFor(node.category).label,
    node.distanceKm?.let { "%.1f km".format(it) },
    formatNodeDate(node.startsAt),
    node.host?.name?.let { "by $it" },
    node.attendeeCount?.let { "$it going" },
    node.memberCount?.let { "$it members" },
).joinToString(" · ")

private fun formatNodeDate(value: String?): String? = value?.let { rawValue ->
    runCatching {
        OffsetDateTime.parse(rawValue).format(DateTimeFormatter.ofPattern("EEE, MMM d · h:mm a"))
    }.recoverCatching {
        LocalDateTime.parse(rawValue).format(DateTimeFormatter.ofPattern("EEE, MMM d · h:mm a"))
    }.getOrNull()
}

private fun communityMapError(throwable: Throwable): String =
    throwable.localizedMessage?.takeIf { it.isNotBlank() }
        ?: "Community could not refresh. Your account data is still safe."
