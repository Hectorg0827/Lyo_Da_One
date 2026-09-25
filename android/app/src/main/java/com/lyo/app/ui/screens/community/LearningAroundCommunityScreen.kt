package com.lyo.app.ui.screens.community

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animate
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Directions
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.LocationSearching
import androidx.compose.material.icons.filled.MailOutline
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityPostDto
import com.lyo.app.data.api.LearningNodeDto
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.nio.charset.StandardCharsets

/**
 * Community: Learning Around Me (map-first), My Community (account state),
 * and Activity. Every account-owned value comes from the backend through
 * [CommunityMapViewModel]; nothing here is stored on the device.
 */
@Composable
fun LearningAroundCommunityScreen(nav: NavHostController) {
    val vm: CommunityMapViewModel = viewModel()
    val context = LocalContext.current
    val snackbar = remember { SnackbarHostState() }
    var selectedTab by remember { mutableIntStateOf(0) }
    var createMenuExpanded by remember { mutableStateOf(false) }

    @SuppressLint("MissingPermission")
    fun readLocation() {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
            .filter { provider -> runCatching { manager.isProviderEnabled(provider) }.getOrDefault(false) }
        val last = providers
            .mapNotNull { provider -> runCatching { manager.getLastKnownLocation(provider) }.getOrNull() }
            .maxByOrNull { it.time }
        if (last != null && System.currentTimeMillis() - last.time < 10 * 60 * 1000) {
            vm.onLocation(last.latitude, last.longitude)
            return
        }
        val provider = providers.firstOrNull()
        if (provider != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.getCurrentLocation(provider, null, ContextCompat.getMainExecutor(context)) { location ->
                when {
                    location != null -> vm.onLocation(location.latitude, location.longitude)
                    last != null -> vm.onLocation(last.latitude, last.longitude)
                    else -> vm.onLocationUnavailable()
                }
            }
        } else if (last != null) {
            vm.onLocation(last.latitude, last.longitude)
        } else {
            vm.onLocationUnavailable()
        }
    }

    val locationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { result ->
        if (result.values.any { it }) readLocation() else vm.onLocationDenied()
    }

    fun requestLocation(explicit: Boolean) {
        val granted = listOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION)
            .any { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }
        if (granted) {
            if (explicit) vm.onLocating()
            readLocation()
        } else {
            locationPermission.launch(
                arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION),
            )
        }
    }

    LaunchedEffect(Unit) {
        vm.start()
        if (!vm.locationRequested) {
            vm.locationRequested = true
            requestLocation(explicit = false)
        } else {
            // Back from a detail page: pick up changes made there or elsewhere.
            vm.refreshAccount()
            vm.loadNearby()
        }
    }
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }
    LaunchedEffect(selectedTab) { if (selectedTab == 2) vm.loadPosts() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "Community",
                        style = MaterialTheme.typography.headlineSmall,
                        color = TextPrimary,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.semantics { heading() },
                    )
                    Text("Learn from the places and people around you", style = MaterialTheme.typography.bodySmall, color = TextSecondary)
                }
                Box {
                    IconButton(onClick = { createMenuExpanded = true }) {
                        Icon(Icons.Default.Add, contentDescription = "Create in Community", tint = TextPrimary)
                    }
                    DropdownMenu(expanded = createMenuExpanded, onDismissRequest = { createMenuExpanded = false }) {
                        DropdownMenuItem(text = { Text("Learning event") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_EVENT) })
                        DropdownMenuItem(text = { Text("Study group") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_GROUP) })
                        DropdownMenuItem(text = { Text("Offer tutoring") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_TUTOR) })
                        DropdownMenuItem(text = { Text("Activity post") }, onClick = { createMenuExpanded = false; nav.navigate(Routes.CREATE_POST) })
                    }
                }
            }

            CommunityTabs(selectedTab = selectedTab, onSelect = { selectedTab = it })

            when (selectedTab) {
                0 -> AroundMeTab(
                    vm = vm,
                    openDetail = { node -> nav.navigate(Routes.communityNode(node.kind, node.id)) },
                    onLocate = { if (!vm.centerOnUser()) requestLocation(explicit = true) },
                    onOpenSettings = {
                        runCatching {
                            context.startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)),
                            )
                        }
                    },
                    onCreateEvent = { nav.navigate(Routes.CREATE_EVENT) },
                )
                1 -> MyCommunityTab(vm = vm, nav = nav)
                else -> CommunityActivityTab(posts = vm.posts, nav = nav)
            }
        }
        SnackbarHost(
            hostState = snackbar,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(16.dp),
        )
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
                    .clickable(role = Role.Tab) { onSelect(index) }
                    .semantics { stateDescription = if (index == selectedTab) "Selected" else "Not selected" },
            ) {
                Text(
                    label,
                    color = if (index == selectedTab) Color.White else TextSecondary,
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.padding(vertical = 12.dp),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// ── Learning Around Me ───────────────────────────────────────────────────────

@Composable
private fun AroundMeTab(
    vm: CommunityMapViewModel,
    openDetail: (LearningNodeDto) -> Unit,
    onLocate: () -> Unit,
    onOpenSettings: () -> Unit,
    onCreateEvent: () -> Unit,
) {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        if (maxWidth >= 840.dp) {
            // Tablets and large windows: results beside the map.
            Row(modifier = Modifier.fillMaxSize()) {
                Column(
                    modifier = Modifier
                        .width(400.dp)
                        .fillMaxHeight()
                        .background(SurfaceElevated),
                ) {
                    CommunityControls(vm = vm, onLocate = onLocate)
                    SheetHeader(vm = vm, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                    SheetBody(vm = vm, openDetail = openDetail, onCreateEvent = onCreateEvent, modifier = Modifier.weight(1f))
                }
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                ) {
                    MapLayer(vm)
                    MapOverlays(vm = vm, onOpenSettings = onOpenSettings, modifier = Modifier.align(Alignment.TopCenter))
                }
            }
        } else {
            val available = maxHeight
            Box(modifier = Modifier.fillMaxSize()) {
                MapLayer(vm)
                Column(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .fillMaxWidth(),
                ) {
                    CommunityControls(vm = vm, onLocate = onLocate)
                    MapOverlays(vm = vm, onOpenSettings = onOpenSettings)
                }
                CommunityBottomSheet(
                    detent = vm.sheet,
                    onDetentChange = { vm.sheet = it },
                    available = available,
                    header = { SheetHeader(vm = vm) },
                    modifier = Modifier.align(Alignment.BottomCenter),
                ) {
                    SheetBody(vm = vm, openDetail = openDetail, onCreateEvent = onCreateEvent, modifier = Modifier.fillMaxSize())
                }
            }
        }
    }
}

@Composable
private fun CommunityControls(vm: CommunityMapViewModel, onLocate: () -> Unit) {
    val focus = LocalFocusManager.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Background.copy(alpha = 0.94f))
            .padding(bottom = 6.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
        ) {
            OutlinedTextField(
                value = vm.queryText,
                onValueChange = { vm.queryText = it },
                singleLine = true,
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                trailingIcon = {
                    if (vm.resolving) {
                        CircularProgressIndicator(color = LyoPurple, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                    } else if (vm.queryText.isNotEmpty() || vm.activeQuery.isNotEmpty()) {
                        IconButton(onClick = { vm.clearSearch() }) {
                            Icon(Icons.Default.Close, contentDescription = "Clear search")
                        }
                    }
                },
                placeholder = { Text("Search a topic, place, or ZIP") },
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = {
                    focus.clearFocus()
                    vm.submitSearch()
                }),
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = onLocate) {
                Icon(
                    if (vm.locationState == LocationState.GRANTED) Icons.Default.MyLocation else Icons.Default.LocationSearching,
                    contentDescription = "Show learning near me",
                    tint = if (vm.locationState == LocationState.GRANTED) LyoPurple else TextSecondary,
                )
            }
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 12.dp),
        ) {
            item {
                FilterChip(
                    selected = vm.filters.isEmpty(),
                    onClick = { vm.clearFilters() },
                    leadingIcon = { Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(16.dp)) },
                    label = { Text("All") },
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = LyoPurple, selectedLabelColor = Color.White, selectedLeadingIconColor = Color.White),
                )
            }
            items(CommunityDiscovery.filters, key = { it.id }) { filter ->
                FilterChip(
                    selected = filter.id in vm.filters,
                    onClick = { vm.toggleFilter(filter.id) },
                    leadingIcon = { Icon(filterIcon(filter.id), contentDescription = null, modifier = Modifier.size(16.dp)) },
                    label = { Text(filter.label) },
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = LyoPurple, selectedLabelColor = Color.White, selectedLeadingIconColor = Color.White),
                )
            }
        }
    }
}

@Composable
private fun MapOverlays(vm: CommunityMapViewModel, onOpenSettings: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 8.dp, start = 12.dp, end = 12.dp),
    ) {
        if (vm.showAreaSearch) {
            Button(
                onClick = { vm.searchThisArea() },
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            ) {
                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("Search this area")
            }
        }
        val showNotice = !vm.locationNoticeDismissed &&
            (vm.locationState == LocationState.DENIED || vm.locationState == LocationState.UNAVAILABLE)
        if (showNotice) {
            Surface(color = SurfaceElevated.copy(alpha = 0.96f), shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
                Row(verticalAlignment = Alignment.Top, modifier = Modifier.padding(12.dp)) {
                    Icon(Icons.Default.LocationOff, contentDescription = null, tint = Color(0xFFA78BFA), modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            if (vm.locationState == LocationState.DENIED) {
                                "Location is off — showing ${vm.areaLabel}. Search a city or ZIP, or allow location."
                            } else {
                                "Couldn't find your location — showing ${vm.areaLabel}. Search a city or ZIP instead."
                            },
                            color = TextSecondary,
                            style = MaterialTheme.typography.bodySmall,
                        )
                        if (vm.locationState == LocationState.DENIED) {
                            TextButton(onClick = onOpenSettings) { Text("Open settings") }
                        }
                    }
                    IconButton(onClick = { vm.locationNoticeDismissed = true }) {
                        Icon(Icons.Default.Close, contentDescription = "Dismiss", tint = TextSecondary)
                    }
                }
            }
        }
    }
}

@Composable
private fun SheetHeader(vm: CommunityMapViewModel, modifier: Modifier = Modifier) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = modifier.fillMaxWidth()) {
        if (vm.selectedKey != null) {
            TextButton(onClick = { vm.closePreview() }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("All results")
            }
            Spacer(Modifier.weight(1f))
        } else {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    vm.resultsTitle,
                    color = TextPrimary,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.semantics { heading() },
                )
                val subtitle = buildList {
                    if (vm.activeQuery.isNotEmpty()) add("“${vm.activeQuery}”")
                    addAll(CommunityDiscovery.activeFilterLabels(vm.filters))
                }
                if (subtitle.isNotEmpty()) {
                    Text(subtitle.joinToString(" · "), color = TextSecondary, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            if (vm.loading) CircularProgressIndicator(color = LyoPurple, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun SheetBody(
    vm: CommunityMapViewModel,
    openDetail: (LearningNodeDto) -> Unit,
    onCreateEvent: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val selected = vm.selectedNode
    if (selected != null) {
        Column(
            modifier = modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 4.dp),
        ) {
            LearningNodeSheet(node = selected, vm = vm, onOpenDetail = { openDetail(selected) })
            Spacer(Modifier.height(32.dp))
        }
    } else {
        ResultsList(vm = vm, openPreview = { vm.select(it) }, onCreateEvent = onCreateEvent, modifier = modifier)
    }
}

@Composable
private fun ResultsList(
    vm: CommunityMapViewModel,
    openPreview: (LearningNodeDto) -> Unit,
    onCreateEvent: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val error = vm.loadError
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 4.dp, bottom = 32.dp),
        modifier = modifier,
    ) {
        if (vm.clusterKeys != null) {
            item {
                OutlinedButton(onClick = { vm.showEverything() }) {
                    Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Show everything in this area")
                }
            }
        }
        if (error != null && vm.nodes.isNotEmpty()) {
            item {
                NoticeRow(Icons.Default.History, "${error.title} Showing earlier results.", if (error.retry) "Retry" else null) { vm.retry() }
            }
        }
        if (vm.degradedSources.isNotEmpty() && error == null) {
            item {
                NoticeRow(Icons.Default.Warning, "Some nearby places couldn't load right now. Events and groups are up to date.", "Retry") { vm.retry() }
            }
        }
        when {
            vm.loading && vm.nodes.isEmpty() -> items(5) { SkeletonRow() }
            error != null && vm.nodes.isEmpty() -> item {
                CommunityStateMessage(
                    title = error.title,
                    body = error.body,
                    actions = if (error.retry) listOf("Try again" to { vm.retry() }) else emptyList(),
                    icon = if (error == CommunityDiscovery.offlineError) Icons.Default.WifiOff else Icons.Default.Place,
                )
            }
            vm.listNodes.isEmpty() && vm.hasLoaded -> item {
                val narrowed = vm.filters.isNotEmpty() || vm.activeQuery.isNotEmpty()
                val actions = buildList<Pair<String, () -> Unit>> {
                    if (vm.filters.isNotEmpty()) add("Clear filters" to { vm.clearFilters() })
                    if (vm.activeQuery.isNotEmpty()) add("Clear search" to { vm.clearSearch() })
                    add("Search a wider area" to { vm.widenSearch() })
                    add("Create an event" to onCreateEvent)
                }
                CommunityStateMessage(
                    title = "No learning opportunities here yet",
                    body = if (narrowed) "Try fewer filters, a different topic, or a wider area."
                    else "Try a wider area, or be the first to host a learning event here.",
                    actions = actions,
                )
            }
            else -> items(vm.listNodes, key = { it.key }) { node ->
                LearningNodeCard(node = node, onClick = { openPreview(node) })
            }
        }
    }
}

@Composable
private fun NoticeRow(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String, action: String?, onAction: () -> Unit) {
    Surface(color = WarningAmber.copy(alpha = 0.12f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)) {
            Icon(icon, contentDescription = null, tint = WarningAmber, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(text, color = TextSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
            if (action != null) TextButton(onClick = onAction) { Text(action) }
        }
    }
}

@Composable
private fun SkeletonRow() {
    Surface(color = SurfaceElevated, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(12.dp)) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp)),
            )
            Spacer(Modifier.width(12.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(14.dp)
                        .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(4.dp)),
                )
                Box(
                    modifier = Modifier
                        .width(180.dp)
                        .height(11.dp)
                        .background(Color.White.copy(alpha = 0.07f), RoundedCornerShape(4.dp)),
                )
            }
        }
    }
}

/** What a marker tap shows: enough to decide, with the main actions, without leaving the map. */
@Composable
private fun LearningNodeSheet(node: LearningNodeDto, vm: CommunityMapViewModel, onOpenDetail: () -> Unit) {
    val context = LocalContext.current
    val color = categoryColor(node.category)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(46.dp)
                    .background(color.copy(alpha = 0.16f), RoundedCornerShape(13.dp)),
            ) {
                Icon(categoryIcon(node.category), contentDescription = null, tint = color)
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(node.categoryLabel().uppercase(), color = color, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                    StatusBadge(node)
                }
                Text(
                    node.title,
                    color = TextPrimary,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.semantics { heading() },
                )
            }
            IconButton(onClick = { vm.closePreview() }) {
                Icon(Icons.Default.Close, contentDescription = "Close preview", tint = TextSecondary)
            }
        }
        node.whenText()?.let { CommunityInfoLine(Icons.Default.Schedule, it) }
        val place = node.placeLine()
        val distance = node.distanceText()
        if (place != null) {
            CommunityInfoLine(Icons.Default.Place, listOfNotNull(place, distance).joinToString(" · "))
        } else if (distance != null) {
            CommunityInfoLine(Icons.Default.Place, distance)
        }
        node.organizerLine()?.let { CommunityInfoLine(Icons.Default.Person, it) }
        node.priceText()?.let { CommunityInfoLine(Icons.Default.Sell, it) }
        node.peopleLine()?.let { CommunityInfoLine(Icons.Default.Groups, it) }
        node.openingHours?.takeIf { it.isNotBlank() }?.let { CommunityInfoLine(Icons.Default.CalendarMonth, it) }
        (node.description ?: node.relevance)?.takeIf { it.isNotBlank() }?.let {
            Text(it, color = TextSecondary, style = MaterialTheme.typography.bodyMedium, maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
        CommunityPrimaryActions(node = node, vm = vm)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Button(
                onClick = onOpenDetail,
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                modifier = Modifier.weight(1f),
            ) {
                Text("View details")
                Spacer(Modifier.width(6.dp))
                Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(18.dp))
            }
            CommunityDiscovery.directionsUrl(node)?.let { url ->
                OutlinedButton(onClick = {
                    vm.track("community_directions_opened", mapOf("kind" to node.kind))
                    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
                }) {
                    Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Directions")
                }
            }
        }
    }
}

// ── Bottom sheet ─────────────────────────────────────────────────────────────

/**
 * Map-first bottom sheet with collapsed, medium, and expanded heights. Drag
 * the handle or tap the header; TalkBack users get an explicit action.
 */
@Composable
private fun CommunityBottomSheet(
    detent: SheetDetent,
    onDetentChange: (SheetDetent) -> Unit,
    available: Dp,
    header: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val density = LocalDensity.current
    val collapsed = 92.dp
    val expanded = maxOf(collapsed + 120.dp, available - 150.dp)
    val medium = minOf(expanded, maxOf(260.dp, available * 0.5f))
    fun heightOf(value: SheetDetent): Dp = when (value) {
        SheetDetent.COLLAPSED -> collapsed
        SheetDetent.MEDIUM -> medium
        SheetDetent.EXPANDED -> expanded
    }
    fun px(value: Dp): Float = with(density) { value.toPx() }
    var heightPx by remember { mutableFloatStateOf(px(heightOf(detent))) }
    var dragging by remember { mutableStateOf(false) }
    LaunchedEffect(detent, available) {
        if (!dragging) animate(heightPx, px(heightOf(detent))) { value, _ -> heightPx = value }
    }
    fun nearest(projectedPx: Float): SheetDetent =
        SheetDetent.entries.minByOrNull { kotlin.math.abs(px(heightOf(it)) - projectedPx) } ?: SheetDetent.MEDIUM
    fun cycle() = onDetentChange(
        when (detent) {
            SheetDetent.COLLAPSED -> SheetDetent.MEDIUM
            SheetDetent.MEDIUM -> SheetDetent.EXPANDED
            SheetDetent.EXPANDED -> SheetDetent.MEDIUM
        },
    )

    Surface(
        color = SurfaceElevated,
        shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
        shadowElevation = 16.dp,
        modifier = modifier
            .fillMaxWidth()
            .height(with(density) { heightPx.toDp() }),
    ) {
        Column {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .draggable(
                        orientation = Orientation.Vertical,
                        state = rememberDraggableState { delta ->
                            heightPx = (heightPx - delta).coerceIn(px(collapsed), px(expanded))
                        },
                        onDragStarted = { dragging = true },
                        onDragStopped = { velocity ->
                            dragging = false
                            val next = nearest(heightPx - velocity * 0.15f)
                            if (next == detent) animate(heightPx, px(heightOf(next))) { value, _ -> heightPx = value }
                            else onDetentChange(next)
                        },
                    )
                    .clickable(
                        onClickLabel = if (detent == SheetDetent.EXPANDED) "Show more map" else "Show more results",
                        role = Role.Button,
                    ) { cycle() }
                    .padding(horizontal = 16.dp),
            ) {
                Box(
                    modifier = Modifier
                        .padding(top = 8.dp, bottom = 8.dp)
                        .width(40.dp)
                        .height(5.dp)
                        .background(Color.White.copy(alpha = 0.35f), RoundedCornerShape(50)),
                )
                header()
                Spacer(Modifier.height(8.dp))
            }
            if (detent != SheetDetent.COLLAPSED || dragging) {
                Box(modifier = Modifier.weight(1f)) { content() }
            }
        }
    }
}

// ── Map ──────────────────────────────────────────────────────────────────────

/** The small, safe subset of a node the map page needs. */
private data class MapPin(
    val key: String,
    val title: String,
    val category: String,
    val latitude: Double?,
    val longitude: Double?,
    val ended: Boolean,
)

@Composable
private fun MapLayer(vm: CommunityMapViewModel) {
    LearningMapWebView(
        nodes = vm.nodes,
        selectedKey = vm.selectedKey,
        command = vm.mapCommand,
        userLocation = vm.userLocation,
        onSelect = vm::selectByKey,
        onCluster = vm::selectCluster,
        onViewport = vm::onViewportChanged,
        modifier = Modifier.fillMaxSize(),
    )
}

/**
 * Leaflet in a WebView, loaded once. Markers, selection, and camera moves are
 * pushed in with small script calls, so panning never reloads the page and
 * the map never refetches data on its own.
 */
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun LearningMapWebView(
    nodes: List<LearningNodeDto>,
    selectedKey: String?,
    command: MapCommand,
    userLocation: Pair<Double, Double>?,
    onSelect: (String) -> Unit,
    onCluster: (List<String>) -> Unit,
    onViewport: (Double, Double, Double, Double, Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val bridge = remember { LearningMapBridge() }
    var ready by remember { mutableStateOf(false) }
    bridge.onSelected = onSelect
    bridge.onCluster = onCluster
    bridge.onViewport = onViewport
    bridge.onReady = { ready = true }
    var webView by remember { mutableStateOf<WebView?>(null) }
    val initial = remember { command }
    AndroidView(
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                webViewClient = WebViewClient()
                setBackgroundColor(0xFF0B1230.toInt())
                contentDescription = "Map of learning opportunities"
                addJavascriptInterface(bridge, "LyoCommunity")
                loadDataWithBaseURL(
                    "https://lyoai.app",
                    learningMapHtml(initial.latitude, initial.longitude, initial.zoom),
                    "text/html",
                    "UTF-8",
                    null,
                )
                webView = this
            }
        },
        modifier = modifier,
    )
    val payload = remember(nodes) {
        val pins = nodes.map { MapPin(it.key, it.title, it.category, it.latitude, it.longitude, it.hasEnded) }
        Base64.encodeToString(ApiClient.gson.toJson(pins).toByteArray(StandardCharsets.UTF_8), Base64.NO_WRAP)
    }
    LaunchedEffect(ready, payload, selectedKey) {
        if (ready) webView?.evaluateJavascript("window.lyoSetNodes('$payload', ${ApiClient.gson.toJson(selectedKey)})", null)
    }
    LaunchedEffect(ready, command.token) {
        if (ready) webView?.evaluateJavascript("window.lyoMoveTo(${command.latitude}, ${command.longitude}, ${command.zoom})", null)
    }
    LaunchedEffect(ready, userLocation) {
        val here = userLocation
        if (ready && here != null) webView?.evaluateJavascript("window.lyoSetUser(${here.first}, ${here.second})", null)
    }
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
    var onCluster: (List<String>) -> Unit = {}
    var onViewport: (Double, Double, Double, Double, Boolean) -> Unit = { _, _, _, _, _ -> }
    var onReady: () -> Unit = {}
    private val main = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun selectNode(key: String) {
        main.post { onSelected(key) }
    }

    @JavascriptInterface
    fun selectCluster(keysJson: String) {
        val keys = runCatching { ApiClient.gson.fromJson(keysJson, Array<String>::class.java).toList() }.getOrDefault(emptyList())
        main.post { onCluster(keys) }
    }

    @JavascriptInterface
    fun viewportChanged(north: Double, south: Double, east: Double, west: Double, programmatic: Boolean) {
        main.post { onViewport(north, south, east, west, programmatic) }
    }

    @JavascriptInterface
    fun ready() {
        main.post { onReady() }
    }
}

private fun learningMapHtml(latitude: Double, longitude: Double, zoom: Int): String = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <style>html,body,#map{height:100%;margin:0;background:#0B1230}
    .pin{display:grid;width:34px;height:34px;place-items:center;border:3px solid #fff;border-radius:50% 50% 50% 8px;color:#fff;font:800 12px sans-serif;box-shadow:0 6px 18px #0008}
    .pin.sel{transform:scale(1.22)}.pin.ended{opacity:.55}
    .cluster{display:grid;width:40px;height:40px;place-items:center;border:3px solid #fff;border-radius:50%;background:#6366F1;color:#fff;font:800 13px sans-serif;box-shadow:0 6px 18px #0008}
    .me{display:block;width:14px;height:14px;border-radius:50%;background:#6366F1;border:3px solid #fff;box-shadow:0 0 0 6px #6366F155}
    .leaflet-control-attribution{background:#0E173Ddd!important;color:#aaa!important}.leaflet-control-attribution a{color:#A78BFA!important}</style>
    </head><body><div id="map"></div><script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script><script>
    const colors={event:'#F97316',workshop:'#F59E0B',class:'#8B5CF6',study_group:'#3B82F6',tutor:'#EC4899',library:'#10B981',museum:'#06B6D4',educational_center:'#6366F1'};
    const glyphs={event:'E',workshop:'W',class:'C',study_group:'G',tutor:'T',library:'L',museum:'M',educational_center:'S'};
    let nodes=[];let selected=null;let programmatic=true;let me=null;
    const map=L.map('map',{zoomControl:false}).setView([$latitude,$longitude],$zoom);
    L.control.zoom({position:'bottomright'}).addTo(map);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'&copy; OpenStreetMap contributors'}).addTo(map);
    const layer=L.layerGroup().addTo(map);
    function pinMarker(n){const cls='pin'+(n.key===selected?' sel':'')+(n.ended?' ended':'');const icon=L.divIcon({className:'',html:'<span class="'+cls+'" style="background:'+(colors[n.category]||'#6366F1')+'">'+(glyphs[n.category]||'•')+'</span>',iconSize:[38,42],iconAnchor:[19,40]});
      L.marker([n.latitude,n.longitude],{icon:icon,title:n.title,keyboard:true,zIndexOffset:n.key===selected?1000:0}).on('click',function(){LyoCommunity.selectNode(n.key)}).addTo(layer)}
    function render(){layer.clearLayers();const z=map.getZoom();const cells=new Map();
      nodes.forEach(function(n){if(!Number.isFinite(n.latitude)||!Number.isFinite(n.longitude))return;const p=map.project([n.latitude,n.longitude],z);const k=Math.floor(p.x/56)+':'+Math.floor(p.y/56);if(!cells.has(k))cells.set(k,[]);cells.get(k).push(n)});
      cells.forEach(function(members){
        if(members.length===1||members.some(function(m){return m.key===selected})){members.forEach(pinMarker);return}
        const lat=members.reduce(function(s,m){return s+m.latitude},0)/members.length;const lng=members.reduce(function(s,m){return s+m.longitude},0)/members.length;
        const icon=L.divIcon({className:'',html:'<span class="cluster">'+members.length+'</span>',iconSize:[44,44],iconAnchor:[22,22]});
        L.marker([lat,lng],{icon:icon,title:members.length+' learning opportunities',keyboard:true}).on('click',function(){const b=L.latLngBounds(members.map(function(m){return [m.latitude,m.longitude]}));
          if(map.getZoom()>=16||b.getNorthEast().distanceTo(b.getSouthWest())<80){LyoCommunity.selectCluster(JSON.stringify(members.map(function(m){return m.key})))}else{map.fitBounds(b.pad(0.5),{maxZoom:17})}}).addTo(layer)})}
    function report(){const b=map.getBounds();LyoCommunity.viewportChanged(b.getNorth(),b.getSouth(),b.getEast(),b.getWest(),programmatic);programmatic=false}
    map.on('zoomend',render);map.on('moveend',report);
    window.lyoSetNodes=function(b64,sel){const bytes=Uint8Array.from(atob(b64),function(c){return c.charCodeAt(0)});nodes=JSON.parse(new TextDecoder().decode(bytes));selected=sel;render();
      const active=nodes.find(function(n){return n.key===sel});if(active&&Number.isFinite(active.latitude)&&!map.getBounds().contains([active.latitude,active.longitude])){programmatic=true;map.panTo([active.latitude,active.longitude])}};
    window.lyoMoveTo=function(lat,lng,zoom){programmatic=true;map.setView([lat,lng],zoom,{animate:false})};
    window.lyoSetUser=function(lat,lng){if(me){me.setLatLng([lat,lng])}else{me=L.marker([lat,lng],{icon:L.divIcon({className:'',html:'<span class="me"></span>',iconSize:[20,20],iconAnchor:[10,10]}),interactive:false,keyboard:false}).addTo(map)}};
    report();LyoCommunity.ready();
    </script></body></html>
""".trimIndent()

// ── My Community ─────────────────────────────────────────────────────────────

@Composable
private fun MyCommunityTab(vm: CommunityMapViewModel, nav: NavHostController) {
    val state = vm.myCommunity
    if (state == null) {
        val error = vm.accountError
        if (error != null) {
            CommunityStateMessage(
                title = error.title,
                body = error.body,
                actions = listOf("Try again" to { vm.refreshAccount() }),
                icon = if (error == CommunityDiscovery.offlineError) Icons.Default.WifiOff else Icons.Default.Person,
            )
        } else {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = LyoPurple) }
        }
        return
    }
    val openNode: (LearningNodeDto) -> Unit = { node -> nav.navigate(Routes.communityNode(node.kind, node.id)) }
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(14.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        item {
            Surface(color = LyoPurple.copy(alpha = 0.14f), shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text("One Community, every device", color = TextPrimary, fontWeight = FontWeight.SemiBold)
                    Text(
                        "Your saves, RSVPs, groups, and hosted events belong to your Lyo account — not this phone.",
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
        state.invited?.takeIf { it.isNotEmpty() }?.let { invited ->
            item { SectionTitle(Icons.Default.MailOutline, "Invited") }
            items(invited, key = { "Invited:${it.key}" }) { node -> LearningNodeCard(node = node, onClick = { openNode(node) }) }
        }
        item { InviteLinkField(onOpen = { token -> nav.navigate(Routes.communityInvite(token)) }) }
        nodeSection(Icons.Default.CheckCircle, "Going", state.going.orEmpty(), "Events you RSVP to appear here on every device.", openNode)
        if (state.going == null && state.attendingEvents.isNotEmpty()) {
            // Older backends list RSVPs only as attending events.
            items(state.attendingEvents, key = { "attending:${it.idStr}" }) { event ->
                AccountCard(
                    title = event.displayTitle,
                    subtitle = listOfNotNull(CommunityDiscovery.formatWhen(event.startTime, event.endTime), event.location).joinToString(" · "),
                    onClick = { nav.navigate(Routes.communityNode("event", event.idStr)) },
                )
            }
        }
        nodeSection(Icons.Default.Star, "Interested", state.interested.orEmpty(), "Tap Interested on an event to keep an eye on it.", openNode)
        nodeSection(Icons.Default.Campaign, "Hosting", state.hosting.orEmpty(), "Events you create appear here, including private drafts.", openNode)
        nodeSection(Icons.Default.Bookmark, "Saved", state.savedNodes, "Save a library, museum, class, or event and it will appear here on every device.", openNode)
        item { SectionTitle(Icons.Default.Groups, "Study groups") }
        items(state.joinedGroups, key = { "group:${it.idStr}" }) { group ->
            AccountCard(
                title = group.name ?: "Study group",
                subtitle = listOfNotNull(
                    group.memberCount?.let { "$it members" },
                    if (group.isOnline == true) "Online" else group.location,
                ).joinToString(" · "),
                onClick = { nav.navigate(Routes.communityNode("study_group", group.idStr)) },
            )
        }
        if (state.joinedGroups.isEmpty()) item { EmptyCommunityText("You haven't joined a study group yet.") }
        item { SectionTitle(Icons.Default.Person, "People you follow") }
        items(state.following, key = { "person:${it.id}" }) { person ->
            AccountCard(title = person.name, subtitle = "Open profile", onClick = { nav.navigate(Routes.userProfile(person.id.toString())) })
        }
        if (state.following.isEmpty()) item { EmptyCommunityText("People you follow will appear here.") }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.nodeSection(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    nodes: List<LearningNodeDto>,
    empty: String,
    openNode: (LearningNodeDto) -> Unit,
) {
    item { SectionTitle(icon, title) }
    items(nodes, key = { "$title:${it.key}" }) { node -> LearningNodeCard(node = node, onClick = { openNode(node) }) }
    if (nodes.isEmpty()) item { EmptyCommunityText(empty) }
}

@Composable
private fun CommunityActivityTab(posts: List<CommunityPostDto>, nav: NavHostController) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(14.dp), modifier = Modifier.fillMaxSize()) {
        items(posts, key = { it.idStr }) { post ->
            Surface(
                color = SurfaceElevated,
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { nav.navigate(Routes.postDetail(post.idStr)) },
            ) {
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
private fun SectionTitle(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
        Icon(icon, contentDescription = null, tint = LyoPurple, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, color = TextPrimary, fontWeight = FontWeight.SemiBold, modifier = Modifier.semantics { heading() })
    }
}

@Composable
private fun AccountCard(title: String, subtitle: String, onClick: (() -> Unit)? = null) {
    Surface(
        color = SurfaceElevated,
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(title, color = TextPrimary, fontWeight = FontWeight.SemiBold)
            if (subtitle.isNotBlank()) Text(subtitle, color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
    }
}
